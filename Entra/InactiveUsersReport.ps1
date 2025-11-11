<#PSScriptInfo
.VERSION 1.3.0
.AUTHOR Kosta Wadenfalk
.COPYRIGHT © 2025 Kosta Wadenfalk. All rights reserved.
.TAGS Microsoft Entra, Microsoft Graph, Audit, Inactive Users, HTML
#>

<#
.SYNOPSIS
  Generate a Microsoft Entra inactive-users analytics report with an interactive HTML dashboard.

.DESCRIPTION
  This script connects to Microsoft Graph using least-privilege read scopes and produces a fully interactive,
  client-side HTML report. No data changes are performed—this is strictly read-only.

  The generated report includes:
    • Summary cards (Total, Enabled/Disabled, Licensed, External, Never Logged In)
    • Inactive user breakdown: ≤30 days, 31–90 days, >90 days
    • Search box and toggle switches (External, Sync Accounts, Enabled Only, etc.)
    • Column-visibility checkboxes (user can hide/show columns dynamically)
    • Preset inactivity filters (Interactive 30d / 90d / Non-Interactive 30d / 90d)
    • Fullscreen table mode
    • CSV export of visible rows and visible columns only

.PARAMETER OutPath
  Directory where the report file will be saved.

.PARAMETER OpenBrowser
  Automatically open the generated HTML report after creation.

#>

param(
    [Parameter(
        Mandatory = $true,
        HelpMessage = "Path where the HTML report should be saved."
    )]
    [ValidateNotNullOrEmpty()]
    [string]$SaveReportTo,

    [switch]$OpenBrowser
)


#-----------------------------#
#  Graph connection (read-only)
#-----------------------------#
function Connect-MgGraphLeastPriv {
  $requiredScopes = @(
    'AuditLog.Read.All',     # required to read signInActivity on users
    'User.Read.All',         # enumerate users + assignedLicenses
    'Organization.Read.All'  # org display name
  )

  $ctx = Get-MgContext -ErrorAction SilentlyContinue
  $needConnect = $true
  if ($ctx) {
    $missing = $requiredScopes | Where-Object { $ctx.Scopes -notcontains $_ }
    if (-not $missing) { $needConnect = $false }
  }

  if ($needConnect) {
    try {
      Connect-MgGraph -Scopes $requiredScopes -NoWelcome -ErrorAction Stop | Out-Null
    } catch {
      throw "Connect-MgGraph failed: $($_.Exception.Message)"
    }
  }
}

#-----------------------------#
#  Data collection
#-----------------------------#
function Get-TenantDisplayName {
  try {
    (Invoke-MgGraphRequest -Uri 'v1.0/organization' -OutputType PSObject).value[0].displayName
  } catch {
    'Unknown Organization'
  }
}

function Get-SkuMap {
  # Map SKU GUID -> SkuPartNumber for quick license name lookups without per-user API calls
  try {
    $skus = Invoke-MgGraphRequest -Uri 'v1.0/subscribedSkus' -OutputType PSObject | Select-Object -ExpandProperty value
    $map = @{}
    foreach ($s in $skus) { $map[$s.skuId] = $s.skuPartNumber }
    $map
  } catch {
    @{}
  }
}

function Get-InactiveUserRows {
  # Pull all users with needed properties in one go
  $props = @(
    'id','userPrincipalName','displayName','userType',
    'createdDateTime','accountEnabled','department','jobTitle',
    'signInActivity',          # requires AuditLog.Read.All
    'assignedLicenses'         # to resolve license presence & names
  )

  $users = Get-MgUser -All -Property $props | Select-Object $props

  $skuMap = Get-SkuMap

  $rows = foreach ($u in $users) {
    $upn     = $u.userPrincipalName
    $type    = if ($u.userType) { $u.userType } else { 'Member' }
    $enabled = [bool]$u.accountEnabled
    $dept    = $u.department
    $title   = $u.jobTitle
    $created = $u.createdDateTime

    $lastInt  = $u.signInActivity.lastSignInDateTime
    $lastNon  = $u.signInActivity.lastNonInteractiveSignInDateTime

    $intDays  = if ($lastInt) { (New-TimeSpan -Start $lastInt).Days } else { $null }
    $nonDays  = if ($lastNon) { (New-TimeSpan -Start $lastNon).Days } else { $null }

    $hasLic   = ($u.assignedLicenses | Measure-Object).Count -gt 0
    $licNames = @()
    foreach ($lic in $u.assignedLicenses) {
      if ($lic.skuId -and $skuMap.ContainsKey($lic.skuId)) { $licNames += $skuMap[$lic.skuId] }
    }
    if (-not $licNames) { $licNames = @('No License Assigned') }

    [PSCustomObject]@{
      UPN                               = $upn
      DisplayName                       = $u.displayName
      UserType                          = $type
      IsExternal                        = ($type -eq 'Guest') -or ($upn -like '*#EXT#*')
      AccountEnabled                    = $enabled
      Department                        = $dept
      JobTitle                          = $title
      CreationDate                      = $created
      LastInteractiveSignInDate         = if ($lastInt) { (Get-Date $lastInt).ToString('yyyy-MM-dd HH:mm') } else { 'Never Logged In' }
      LastNonInteractiveSignInDate      = if ($lastNon) { (Get-Date $lastNon).ToString('yyyy-MM-dd HH:mm') } else { 'Never Logged In' }
      InactiveDaysInteractive           = if ($intDays -ne $null) { $intDays } else { '-' }
      InactiveDaysNonInteractive        = if ($nonDays -ne $null) { $nonDays } else { '-' }
      LicenseDetails                    = ($licNames -join ', ')
      Licensed                          = $hasLic
      CategoryInteractive               = if ($intDays -eq $null) { 'Never' }
                                          elseif ($intDays -le 30) { '≤30' }
                                          elseif ($intDays -le 90) { '31–90' }
                                          else { '>90' }
    }
  }

  $rows
}

#-----------------------------#
#  HTML report
#-----------------------------#
function Write-InactiveUsersHtml {
  param(
    [Parameter(Mandatory)][array]$Rows,
    [Parameter(Mandatory)][string]$Tenant,
    [Parameter(Mandatory)][string]$OutputFile
  )

  # Summary metrics
  $total             = $Rows.Count
  $enabledCount      = ($Rows | Where-Object { $_.AccountEnabled }).Count
  $disabledCount     = $total - $enabledCount
  $licensedCount     = ($Rows | Where-Object { $_.Licensed }).Count
  $externalCount     = ($Rows | Where-Object { $_.IsExternal }).Count
  $neverLoggedCount  = ($Rows | Where-Object { $_.LastInteractiveSignInDate -eq 'Never Logged In' }).Count

  $int30             = ($Rows | Where-Object { $_.CategoryInteractive -eq '≤30' }).Count
  $int90             = ($Rows | Where-Object { $_.CategoryInteractive -eq '31–90' }).Count
  $int90plus         = ($Rows | Where-Object { $_.CategoryInteractive -eq '>90' }).Count

  # Table column definitions (order matters). Pair of header + property name.
  $cols = @(
    @{h='UPN';                                  p='UPN'}
    @{h='Display Name';                          p='DisplayName'}
    @{h='User Type';                             p='UserType'}
    @{h='Account Enabled';                       p='AccountEnabled'}
    @{h='Licensed';                              p='Licensed'}
    @{h='License Details';                       p='LicenseDetails'}
    @{h='Department';                            p='Department'}
    @{h='Job Title';                             p='JobTitle'}
    @{h='Last Interactive SignIn Date';          p='LastInteractiveSignInDate'}
    @{h='Inactive Days (Interactive)';           p='InactiveDaysInteractive'}
    @{h='Last Non Interactive SignIn Date';      p='LastNonInteractiveSignInDate'}
    @{h='Inactive Days (Non-Interactive)';       p='InactiveDaysNonInteractive'}
    @{h='Creation Date';                         p='CreationDate'}
  )

  $date = Get-Date -Format 'MMMM d, yyyy'

  # Build HTML (single file, embedded JS/CSS)
  $sb = [System.Text.StringBuilder]::new()
  [void]$sb.AppendLine(@"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Microsoft Entra Inactive Users Report</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  body{font-family:'Segoe UI',Arial,sans-serif;margin:0;background:#f5f5f5;color:#333}
  .header{background:linear-gradient(135deg,#0078D4 0%,#106EBE 100%);color:#fff;padding:24px 36px}
  .header h1{margin:0;font-size:26px;font-weight:600}
  .header .meta{margin-top:6px;font-size:13px;opacity:.95}
  .wrap{max-width:1550px;margin:0 auto;padding:20px}
  .cards{display:flex;gap:18px;flex-wrap:wrap;margin-bottom:18px}
  .card{background:#fff;border-radius:8px;box-shadow:0 1px 4px rgb(0 0 0 / .08);padding:16px 18px;min-width:240px;flex:1}
  .card .t{font-size:13px;color:#666;margin-bottom:6px}
  .card .v{font-size:24px;font-weight:700;color:#0078D4}
  .filters{display:flex;gap:10px;align-items:center;margin:12px 0 10px 0;flex-wrap:wrap}
  input[type=text]{padding:10px;border:1px solid #ddd;border-radius:4px;min-width:300px}
  .switch{position:relative;display:inline-block;width:52px;height:28px}
  .switch input{opacity:0;width:0;height:0}
  .slider{position:absolute;cursor:pointer;top:0;left:0;right:0;bottom:0;background:#ccc;transition:.3s;border-radius:28px}
  .slider:before{position:absolute;content:"""";height:20px;width:20px;left:4px;bottom:4px;background:white;transition:.3s;border-radius:50%}
  .switch input:checked + .slider{background:#0078D4}
  .switch input:checked + .slider:before{transform:translateX(24px)}
  .switch-lbl{font-size:14px;margin-right:12px}
  .btn{padding:8px 14px;background:#eee;border:0;border-radius:4px;cursor:pointer}
  .btn:hover{background:#ddd}
  .btn.primary{background:#0078D4;color:#fff}
  .btn.primary:hover{background:#106EBE}
  .btn-group{margin-left:auto;display:flex;gap:10px}
  .table-wrap{background:#fff;border-radius:8px;box-shadow:0 1px 6px rgb(0 0 0 / .1);overflow:auto}
  table{width:100%;border-collapse:collapse;min-width:900px}
  th,td{padding:10px 12px;border-bottom:1px solid #eee;text-align:left;white-space:nowrap}
  thead th{position:sticky;top:0;background:#0078D4;color:#fff;font-weight:600}
  tr:nth-child(even){background:#fafafa}
  .modal{display:none;position:fixed;inset:0;background:rgb(0 0 0 / .8);z-index:1000}
  .modal-content{background:#fff;margin:2% auto;padding:18px;width:95%;border-radius:8px}
  .close{position:absolute;right:20px;top:12px;font-size:28px;color:#666;cursor:pointer}
  .colpicker{display:flex;gap:12px;flex-wrap:wrap;margin:10px 0 14px}
  .badge{display:inline-block;padding:2px 8px;border-radius:9999px;background:#eef;border:1px solid #cfe;color:#225}
</style>
</head>
<body>
<div class="header">
  <h1>Microsoft Entra Inactive Users Report</h1>
  <div class="meta">Generated: $date &nbsp;&nbsp;|&nbsp;&nbsp; Org: $tenant</div>
</div>

<div class="wrap">

  <div class="cards">
    <div class="card"><div class="t">Total Users</div><div class="v" id="v_total">$total</div></div>
    <div class="card"><div class="t">Enabled / Disabled</div><div class="v" id="v_ed">$enabledCount / $disabledCount</div></div>
    <div class="card"><div class="t">Licensed Users</div><div class="v" id="v_lic">$licensedCount</div></div>
    <div class="card"><div class="t">External (Guests)</div><div class="v" id="v_ext">$externalCount</div></div>
    <div class="card"><div class="t">Never Logged In (Interactive)</div><div class="v" id="v_never">$neverLoggedCount</div></div>
  </div>

  <div class="cards">
    <div class="card"><div class="t">Interactive Sign-ins &le; 30 days</div><div class="v" id="v_30">$int30</div></div>
           <div class="card"><div class="t">Interactive Sign-ins 31-90 days</div><div class="v" id="v_90">$int90</div></div>
           <div class="card"><div class="t">Interactive Sign-ins &gt; 90 days</div><div class="v" id="v_90p">$int90plus</div></div>
  </div>

  <div class="filters">
    <input id="search" type="text" placeholder="Search UPN or Display Name..." onkeyup="filterSearch()" />
    <label class="switch-lbl"><span class="switch"><input id="hideExt" type="checkbox" onchange="applyFilters()"><span class="slider"></span></span> Hide External</label>
    <label class="switch-lbl"><span class="switch"><input id="hideSync" type="checkbox" onchange="applyFilters()"><span class="slider"></span></span> Hide Sync_ Accounts</label>
    <label class="switch-lbl"><span class="switch"><input id="onlyEnabled" type="checkbox" onchange="applyFilters()"><span class="slider"></span></span> Only Enabled</label>
    <label class="switch-lbl"><span class="switch"><input id="onlyDisabled" type="checkbox" onchange="applyFilters()"><span class="slider"></span></span> Only Disabled</label>
    <label class="switch-lbl"><span class="switch"><input id="onlyLicensed" type="checkbox" onchange="applyFilters()"><span class="slider"></span></span> Only Licensed</label>
    <label class="switch-lbl"><span class="switch"><input id="hideNever" type="checkbox" onchange="applyFilters()"><span class="slider"></span></span> Hide Never Logged In</label>
    <div class="btn-group">
      <button class="btn" onclick="exportCSV()">Export CSV</button>
      <button class="btn" onclick="openModal()">Expand</button>
    </div>
  </div>

  <div><span class="badge">Preset filters:</span>
    <button class="btn" onclick="setPreset('all')">All</button>
           <button class="btn" onclick="setPreset('int30')">Int &le; 30d</button>
           <button class="btn" onclick="setPreset('int90')">Int 31&ndash;90d</button>
           <button class="btn" onclick="setPreset('int90p')">Int &gt; 90d</button>
           <button class="btn" onclick="setPreset('non30')">Non-Int &le; 30d</button>
           <button class="btn" onclick="setPreset('non90')">Non-Int 31&ndash;90d</button>
           <button class="btn" onclick="setPreset('non90p')">Non-Int &gt; 90d</button>
  </div>

  <div class="colpicker" id="colpicker">
    <!-- checkboxes inserted by script -->
  </div>

  <div class="table-wrap">
    <table id="tbl">
      <thead>
        <tr>
"@)

  # headers
  for ($i=0; $i -lt $cols.Count; $i++) {
    $h = [System.Web.HttpUtility]::HtmlEncode($cols[$i].h)
    [void]$sb.AppendLine("          <th data-colix=""$i"">$h</th>")
  }

  [void]$sb.AppendLine("        </tr></thead><tbody>")

  # rows
  foreach ($r in $Rows) {
    $isSync = if ($r.UPN -like 'Sync_*' -or $r.UPN -like 'ADToAADSyncServiceAccount*') { 'true' } else { 'false' }
    $attrs = @()
    if ($r.IsExternal) { $attrs += "data-external='true'" }
    if ($r.AccountEnabled) { $attrs += "data-enabled='true'" } else { $attrs += "data-disabled='true'" }
    if ($r.Licensed) { $attrs += "data-licensed='true'" }
    if ($r.LastInteractiveSignInDate -eq 'Never Logged In') { $attrs += "data-never='true'" }
    $attrs += "data-sync='$isSync'"
    $attrs += "data-intcat='$($r.CategoryInteractive)'"  # ≤30 / 31–90 / >90 / Never

    [void]$sb.AppendLine("        <tr $(($attrs -join ' '))>")
    foreach ($c in $cols) {
      $v = $r.($c.p)
      if ($v -is [datetime]) { $v = $v.ToString('yyyy-MM-dd HH:mm') }
      if ($v -is [bool]) { $v = $(if ($v) {'Yes'} else {'No'}) }
      $v = [System.Web.HttpUtility]::HtmlEncode([string]$v)
      [void]$sb.AppendLine("          <td>$v</td>")
    }
    [void]$sb.AppendLine("        </tr>")
  }

  [void]$sb.AppendLine(@"
      </tbody>
    </table>
  </div>
</div>

<div id="modal" class="modal" onclick="if(event.target.id==='modal'){closeModal()}">
  <div class="modal-content">
    <span class="close" onclick="closeModal()">&times;</span>
    <h3>Inactive Users — Fullscreen</h3>
    <div class="table-wrap" id="modalTableWrap"></div>
  </div>
</div>

<script>
  // Build column checkbox picker
  (function(){
    const headers = document.querySelectorAll('#tbl thead th');
    const picker = document.getElementById('colpicker');
    headers.forEach((th, ix) => {
      const lbl = document.createElement('label');
      const cb  = document.createElement('input');
      cb.type = 'checkbox';
      cb.checked = true;
      cb.dataset.colix = ix;
      cb.onchange = () => toggleColumn(ix, cb.checked);
      lbl.appendChild(cb);
      lbl.appendChild(document.createTextNode(' ' + th.textContent));
      picker.appendChild(lbl);
    });
  })();

  function toggleColumn(ix, show){
    const table = document.getElementById('tbl');
    const hs = table.querySelectorAll('th[data-colix]');
    hs.forEach(h => { if(+h.dataset.colix===ix){ h.style.display = show ? '' : 'none'; }});
    const rows = table.querySelectorAll('tbody tr');
    rows.forEach(r => {
      const cells = r.querySelectorAll('td');
      if (ix < cells.length) cells[ix].style.display = show ? '' : 'none';
    });
  }

  function filterSearch(){ applyFilters(); }

  function setPreset(name){
    const t = document.getElementById('tbl');
    const rows = t.tBodies[0].rows;
    for (let i=0;i<rows.length;i++){
      const r = rows[i];
      let show = true;
      const intcat = r.dataset.intcat || '';
      if (name==='all') show = true;
      else if (name==='int30')  show = (intcat==='≤30');
      else if (name==='int90')  show = (intcat==='31–90');
      else if (name==='int90p') show = (intcat==='>90');
      else if (name==='non30')  show = (r.cells[10].textContent!=='Never Logged In' && parseInt(r.cells[11].textContent) <= 30);
      else if (name==='non90')  show = (r.cells[10].textContent!=='Never Logged In' && parseInt(r.cells[11].textContent) > 30 && parseInt(r.cells[11].textContent) <= 90);
      else if (name==='non90p') show = (r.cells[10].textContent!=='Never Logged In' && parseInt(r.cells[11].textContent) > 90);
      r.style.display = show ? '' : 'none';
    }
  }

  function applyFilters(){
    const q = (document.getElementById('search').value || '').toLowerCase();
    const hideExt = document.getElementById('hideExt').checked;
    const hideSync = document.getElementById('hideSync').checked;
    const onlyEn = document.getElementById('onlyEnabled').checked;
    const onlyDis = document.getElementById('onlyDisabled').checked;
    const onlyLic = document.getElementById('onlyLicensed').checked;
    const hideNever = document.getElementById('hideNever').checked;

    const t = document.getElementById('tbl');
    const rows = t.tBodies[0].rows;

    for (let i=0;i<rows.length;i++){
      const r = rows[i];
      const upn = r.cells[0].textContent.toLowerCase();
      const dn  = r.cells[1].textContent.toLowerCase();

      let show = true;
      if (q && !(upn.includes(q) || dn.includes(q))) show = false;
      if (hideExt && r.dataset.external==='true') show = false;
      if (hideSync && r.dataset.sync==='true') show = false;
      if (onlyEn && !r.hasAttribute('data-enabled')) show = false;
      if (onlyDis && !r.hasAttribute('data-disabled')) show = false;
      if (onlyLic && !r.hasAttribute('data-licensed')) show = false;
      if (hideNever && r.hasAttribute('data-never')) show = false;

      r.style.display = show ? '' : 'none';
    }
  }

  function openModal(){
    const modal = document.getElementById('modal');
    const wrap = document.getElementById('modalTableWrap');
    wrap.innerHTML = '';
    const clone = document.getElementById('tbl').cloneNode(true);
    clone.id = 'tblFull';
    wrap.appendChild(clone);
    // mirror hidden columns
    const hs = document.querySelectorAll('#tbl thead th');
    hs.forEach((h,ix)=>{
      const fullH = clone.querySelectorAll('th')[ix];
      const rows = clone.querySelectorAll('tbody tr');
      if (h.style.display==='none'){ fullH.style.display='none'; rows.forEach(r=>{ if (r.cells[ix]) r.cells[ix].style.display='none'; }); }
    });
    modal.style.display = 'block';
    document.body.style.overflow = 'hidden';
  }
  function closeModal(){ document.getElementById('modal').style.display='none'; document.body.style.overflow='auto'; }

  function exportCSV(){
    const table = document.getElementById('tbl');
    const hs = table.querySelectorAll('thead th');
    const visibleColIdx = [];
    let header = [];
    hs.forEach((h,ix)=>{ if (h.style.display!=='none'){ visibleColIdx.push(ix); header.push('"' + h.textContent.replace(/"/g,'""') + '"'); } });

    let lines = [];
    lines.push(header.join(','));

    const rows = table.querySelectorAll('tbody tr');
    for (let i=0;i<rows.length;i++){
      if (rows[i].style.display==='none') continue;
      const cells = rows[i].querySelectorAll('td');
      let row = [];
      visibleColIdx.forEach(ix=>{
        let txt = cells[ix] ? cells[ix].textContent.trim() : '';
        txt = txt.replace(/"/g,'""');
        row.push('"' + txt + '"');
      });
      lines.push(row.join(','));
    }

    const csv = '\uFEFF' + lines.join('\r\n');
    const a = document.createElement('a');
    a.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csv);
    a.download = 'Entra_Inactive_Users_Report_' + new Date().toISOString().slice(0,10) + '.csv';
    a.click();
  }
</script>

</body>
</html>
"@)

  $null = New-Item -ItemType Directory -Path $SaveReportTo -ErrorAction SilentlyContinue
  $sb.ToString() | Out-File -FilePath $OutputFile -Encoding UTF8
}

#-----------------------------#
#  Main
#-----------------------------#
try {
  Connect-MgGraphLeastPriv
  $tenant = Get-TenantDisplayName
  $rows   = Get-InactiveUserRows

  $outfile = Join-Path -Path $SaveReportTo -ChildPath 'Entra_Inactive_Users_Report.html'
  Write-InactiveUsersHtml -Rows $rows -Tenant $tenant -OutputFile $outfile

  Write-Host "HTML report: $outfile"
  if ($OpenBrowser) { Start-Process $outfile }
}
catch {
  Write-Error $_
}
