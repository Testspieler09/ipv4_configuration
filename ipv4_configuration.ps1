<#
.AUTHOR
Testspieler09
.DESCRIPTION
A script to configurate the IPv4 settings on Windows with or without GUI.
.VERSION
1.0.0
#>

param()

function Test-IsAdmin {
	$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
	$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
	try {
		Set-NetIPInterface -ErrorAction Stop
		$net_priveleges = $true
	} catch {
		$net_priveleges = $false
	}
	return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -or $net_priveleges
}

function IsValidIPv4Address {
	param([string]$ip)
	return ($ip -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$" -and [bool]($ip -as [ipaddress]))
}

function IsValidSubnetMask {
	param ([string]$subnetMask)
	return [System.Net.IPAddress]::TryParse($subnetMask, [ref]$null)
}

function Convert-SubnetMaskToPrefixLength {
	param ([string]$subnetMask)
	$binaryMask = [Convert]::ToString([BitConverter]::ToUInt32([System.Net.IPAddress]::Parse($subnetMask).GetAddressBytes(), 0), 2)
	return ($binaryMask -split '1').Length - 1
}

function Apply-IPconfig {
	param([Array]$arguments)
	if ($arguments.choice_1 -match "[dD]") {
		try {
			Set-NetIPInterface -InterfaceAlias $arguments.name -Dhcp Enabled -ErrorAction Stop
			Write-Host "DHCP is enabled for $($arguments.name) now" -f Blue
		} catch {
			Write-Host "`nAn error occured:" -f Blue
			Write-Host $_ -f Red
		}
	} elseif ($arguments.choice_1 -match "[iI]") {

		$params = @{
			InterfaceAlias = $arguments.name
			AddressFamily = "IPv4"
		}

		# IPv4 Address
		if (IsValidIPv4Address $arguments.ip) {
			$params.IPAddress = $arguments.ip
		} else {
			Write-Host "The provided input '$($arguments.ip)' is not a valid IPv4-Address." -f Red
			return
		}

		# Subnetmask
		if (IsValidSubnetMask $arguments.mask) {
			$params.PrefixLength = Convert-SubnetMaskToPrefixLength $arguments.mask
		} else {
			Write-Host "The provided input '$($arguments.mask)' is not a valid subnetmask." -f Red
			return
		}

		# Defaultgateway
		if ($arguments.choice_2 -match "[yY]") {
			if (IsValidIPv4Address $arguments.gateway) {
				$params.DefaultGateway = $arguments.gateway
			} else {
				Remove-NetRoute -InterfaceAlias $arguments.name -Confirm:$false -ErrorAction Stop
				Write-Host "Removed defaultgateway from $($arguments.name)" -f Blue
			}
		}

		try {
			Set-NetIPInterface -InterfaceAlias $arguments.name -Dhcp Disabled -ErrorAction Stop
			Write-Host "DHCP is deactivated for $($arguments.name) now" -f Blue
			Remove-NetIPAddress -InterfaceAlias $arguments.name -Confirm:$false -ErrorAction Stop
			Write-Host "Removed the IP-Address from $($arguments.name) now" -f Blue
			New-NetIPAddress @params -ErrorAction Stop | Out-Null
			Write-Host "Set the provided settings for $($arguments.name) now" -f Green
		} catch {
			Write-Host "`nAn error occurred:" -f Blue
			Write-Host $_ -f Red
		}
	}

	# Set DNS
	if ($arguments.choice_3 -notmatch "[yY]") {
		return
	}

	if (!(IsValidIPv4Address $arguments.dns_2) -and !(IsValidIPv4Address $arguments.dns_1)) {
		Set-DnsClientServerAddress -InterfaceAlias $arguments.name -ResetServerAddresses
		Write-Host "The DNS server addresses are reset now" -f Blue
	} else {
		Set-DnsClientServerAddress -InterfaceAlias $arguments.name -ServerAddresses ("$($arguments.dns_1)", "$($arguments.dns_2)")
		Write-Host "The DNS server addresses are set to the provided ones now" -f Blue
	}
}

# use function instead of class because of this issue:
# https://stackoverflow.com/questions/69019962/how-can-i-import-load-a-dll-file-to-use-in-a-powershell-script-without-getting/69104097#69104097
function GUI {
	param([string]$name)
	Add-Type -AssemblyName System.Windows.Forms
	Add-Type -AssemblyName System.Drawing

	# Form and groups
	$form = New-Object System.Windows.Forms.Form
	$form.Text = "IPv4 Configuration"
	$form.Size = New-Object System.Drawing.Size(385, 430)
	$form.StartPosition = "CenterScreen"
	$form.FormBorderStyle = "FixedDialog"
	$form.MaximizeBox = $false
	$form.MaximumSize = $form.Size
	$form.MinimumSize = $form.Size

	$dhcpGroupBox = New-Object System.Windows.Forms.GroupBox
	$dhcpGroupBox.Text = "DHCP Settings"
	$dhcpGroupBox.Location = New-Object System.Drawing.Point(10, 10)
	$dhcpGroupBox.Size = New-Object System.Drawing.Size(350, 180)
	$form.Controls.Add($dhcpGroupBox)

	$dnsGroupBox = New-Object System.Windows.Forms.GroupBox
	$dnsGroupBox.Text = "DNS Settings"
	$dnsGroupBox.Location = New-Object System.Drawing.Point(10, 200)
	$dnsGroupBox.Size = New-Object System.Drawing.Size(350, 150)
	$form.Controls.Add($dnsGroupBox)

	# OK and CANCEL button
	$okButton = New-Object System.Windows.Forms.Button
	$okButton.Location = New-Object System.Drawing.Point(195,360)
	$okButton.Size = New-Object System.Drawing.Size(75,23)
	$okButton.Text = 'OK'
	$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
	$form.AcceptButton = $okButton
	$form.Controls.Add($okButton)

	$cancelButton = New-Object System.Windows.Forms.Button
	$cancelButton.Location = New-Object System.Drawing.Point(280,360)
	$cancelButton.Size = New-Object System.Drawing.Size(75,23)
	$cancelButton.Text = 'Cancel'
	$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
	$form.CancelButton = $cancelButton
	$form.Controls.Add($cancelButton)

	# Radio button
	$dhcpEnableRadio = New-Object System.Windows.Forms.RadioButton
	$dhcpEnableRadio.Text = "Enable DHCP"
	$dhcpEnableRadio.Location = New-Object System.Drawing.Point(10, 20)
	$dhcpEnableRadio.Checked = $true
	$dhcpGroupBox.Controls.Add($dhcpEnableRadio)

	$dhcpDisableRadio = New-Object System.Windows.Forms.RadioButton
	$dhcpDisableRadio.Text = "Disable DHCP"
	$dhcpDisableRadio.Location = New-Object System.Drawing.Point(10, 50)
	$dhcpGroupBox.Controls.Add($dhcpDisableRadio)

	$dnsEnableRadio = New-Object System.Windows.Forms.RadioButton
	$dnsEnableRadio.Text = "Automatic DNS"
	$dnsEnableRadio.Width = 170
	$dnsEnableRadio.Location = New-Object System.Drawing.Point(10, 20)
	$dnsEnableRadio.Checked = $true
	$dnsGroupBox.Controls.Add($dnsEnableRadio)

	$dnsDisableRadio = New-Object System.Windows.Forms.RadioButton
	$dnsDisableRadio.Text = "Set DNS"
	$dnsDisableRadio.Location = New-Object System.Drawing.Point(10, 50)
	$dnsGroupBox.Controls.Add($dnsDisableRadio)

	# Ip config
	$ip_label = New-Object System.Windows.Forms.Label
	$ip_label.Location = New-Object System.Drawing.Point(10,80)
	$ip_label.Text = 'IPv4 Address:'
	$dhcpGroupBox.Controls.Add($ip_label)

	$ip_address_input = New-Object System.Windows.Forms.MaskedTextBox
	$ip_address_input.Mask = "000\.000\.000\.000"
	$ip_address_input.ValidatingType = [System.Net.IPAddress]
	$ip_address_input.Location = New-Object System.Drawing.Point(120,80)
	$ip_address_input.Width = 200
	$ip_address_input.Font = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Bold)
	$ip_address_input.TextAlign = "Center"
	$ip_address_input.Enabled = $false
	$dhcpGroupBox.Controls.Add($ip_address_input)

	$subnet_label = New-Object System.Windows.Forms.Label
	$subnet_label.Location = New-Object System.Drawing.Point(10,110)
	$subnet_label.Text = 'Subnet Mask:'
	$dhcpGroupBox.Controls.Add($subnet_label)

	$subnet_input = New-Object System.Windows.Forms.MaskedTextBox
	$subnet_input.Mask = "000\.000\.000\.000"
	$subnet_input.ValidatingType = [System.Net.IPAddress]
	$subnet_input.Location = New-Object System.Drawing.Point(120,110)
	$subnet_input.Width = 200
	$subnet_input.Font = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Bold)
	$subnet_input.TextAlign = "Center"
	$subnet_input.Enabled = $false
	$dhcpGroupBox.Controls.Add($subnet_input)

	$gate_label = New-Object System.Windows.Forms.Label
	$gate_label.Location = New-Object System.Drawing.Point(10,140)
	$gate_label.Text = 'Default Gateway:'
	$dhcpGroupBox.Controls.Add($gate_label)

	$gate_input = New-Object System.Windows.Forms.MaskedTextBox
	$gate_input.Mask = "000\.000\.000\.000"
	$gate_input.ValidatingType = [System.Net.IPAddress]
	$gate_input.Location = New-Object System.Drawing.Point(120,140)
	$gate_input.Width = 200
	$gate_input.Font = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Bold)
	$gate_input.TextAlign = "Center"
	$gate_input.Enabled = $false
	$dhcpGroupBox.Controls.Add($gate_input)

	# DNS config
	$dns_one_label = New-Object System.Windows.Forms.Label
	$dns_one_label.Location = New-Object System.Drawing.Point(10,80)
	$dns_one_label.Text = 'Primary DNS:'
	$dnsGroupBox.Controls.Add($dns_one_label)

	$primary_dns_input = New-Object System.Windows.Forms.MaskedTextBox
	$primary_dns_input.Mask = "000\.000\.000\.000"
	$primary_dns_input.ValidatingType = [System.Net.IPAddress]
	$primary_dns_input.Location = New-Object System.Drawing.Point(120,80)
	$primary_dns_input.Width = 200
	$primary_dns_input.Font = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Bold)
	$primary_dns_input.TextAlign = "Center"
	$primary_dns_input.Enabled = $false
	$dnsGroupBox.Controls.Add($primary_dns_input)

	$dns_two_label = New-Object System.Windows.Forms.Label
	$dns_two_label.Location = New-Object System.Drawing.Point(10,110)
	$dns_two_label.Text = 'Secondary DNS:'
	$dnsGroupBox.Controls.Add($dns_two_label)

	$secondary_dns_input = New-Object System.Windows.Forms.MaskedTextBox
	$secondary_dns_input.Mask = "000\.000\.000\.000"
	$secondary_dns_input.ValidatingType = [System.Net.IPAddress]
	$secondary_dns_input.Location = New-Object System.Drawing.Point(120,110)
	$secondary_dns_input.Width = 200
	$secondary_dns_input.Font = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Bold)
	$secondary_dns_input.TextAlign = "Center"
	$secondary_dns_input.Enabled = $false
	$dnsGroupBox.Controls.Add($secondary_dns_input)

	$form.Topmost = $true

	$toggleDHCPFields = {
		$ip_address_input.Enabled = -not $dhcpEnableRadio.Checked
		$subnet_input.Enabled = -not $dhcpEnableRadio.Checked
		$gate_input.Enabled = -not $dhcpEnableRadio.Checked
	}

	$dhcpEnableRadio.Add_CheckedChanged($toggleDHCPFields)
	$dhcpDisableRadio.Add_CheckedChanged($toggleDHCPFields)

	$toggleDNSFields = {
		$primary_dns_input.Enabled = -not $dnsEnableRadio.Checked
		$secondary_dns_input.Enabled = -not $dnsEnableRadio.Checked
	}

	$dnsEnableRadio.Add_CheckedChanged($toggleDNSFields)
	$dnsDisableRadio.Add_CheckedChanged($toggleDNSFields)

	$result = $form.ShowDialog()
	if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
		$settings = @{
			name = $name
			choice_1 = If ($dhcpEnableRadio.Checked) {"d"} Else {"i"}
			ip = $ip_address_input.Text -replace "\s", ""
			mask = $subnet_input.Text -replace "\s", ""
			choice_2 = If ($dhcpDisableRadio.Checked) {"y"} Else {"n"}
			gateway = $gate_input.Text -replace "\s", ""
			choice_3 = If ($dnsDisableRadio.Checked) {"y"} Else {"n"}
			dns_1 = $primary_dns_input.Text -replace "\s", ""
			dns_2 = $secondary_dns_input.Text -replace "\s", ""
		}
		Apply-IPconfig $settings
	}
}

function Open-Network-Config {
	param(
		[string]$name
	)

	Write-Host ("`nThe script will now simulate the key presses that" +
				" are needed to get to the IPv4 properties of the adapter.") -f Blue
	Write-Host "!!Close the control panel before starting the procedure!!" -f Red
	Write-Host "Please do not press anything during this progress" -f Red
	$choice = Read-Host "Do you want to continue? [y/N] "

	if ($choice -notmatch "[yY]") {
		return
	}

	Start-Process "ncpa.cpl"

	Start-Sleep -Seconds 1.5

	$shell = New-Object -ComObject WScript.Shell

	# THE AUTOMATION FOR HELP SEE https://ss64.com/vb/sendkeys.html
	# Make display type = list
	$shell.SendKeys("^+6")
	# Nav to search input
	$shell.SendKeys("+{TAB}")
	$shell.SendKeys("+{TAB}")
	# search for adapter
	$shell.SendKeys($name)
	Start-Sleep -Seconds 1
	# Select adapter
	$shell.SendKeys("{TAB}")
	$shell.SendKeys("{TAB}")
	$shell.SendKeys("{DOWN}")
	$shell.SendKeys("%{ENTER}")
	Start-Sleep -Seconds 1

	# Navigate to IPv4
	for ($i = 0; $i -lt 5; $i++) {
		$shell.SendKeys("{DOWN}")
		Start-Sleep -Milliseconds 50
	}

	# Select properties
	$shell.SendKeys("{TAB}")
	$shell.SendKeys("{TAB}")
	$shell.SendKeys("{ENTER}")
}

function Use-CLI {
	param(
		[string]$name
	)

	$settings = @{
		name = $name
	}

	# Set IP via DHCP or manually
	while ($true) {
		$choice = Read-Host "`nDo you want to use [D]HCP or set the [I]Pv4-Address manually?"
		if ($choice -match "[dDiI]") {
			$settings.choice_1 = $choice
			break
		} else {
			Write-Host "Invalid Option '$choice'. Please choose 'D' or 'I'" -f Red
		}
	}

	if ($choice -match "[iI]") {

		# IPv4 Address
		$settings.ip = Read-Host "Set the IPAddress to"

		# Subnetmask
		$settings.mask = Read-Host "Set the subnetmask to"

		# Defaultgateway
		$settings.choice_2 = Read-Host "Do you want to change the defaultgateway? [y/N]"
		if ($settings.choice_2 -match "[yY]") {
			$settings.gateway = Read-Host "Set the defaultgateway to"
		}
	}

	# Set DNS
	$settings.choice_3 = Read-Host "Would you like to set your DNS? [y/N]"
	if ($settings.choice_3 -match "[yY]") {
		$settings.dns_1 = Read-Host "Please provide the primary DNS-Server"
		if (!(IsValidIPv4Address $settings.dns_1)) {
			Write-Host ("The input '$($settings.dns_1)' isn't a valid IPv4-Address." +
						" Thus the secondary input will be the primary DNS." +
						" If it is also invalid the script will reset the DNS server addresses.") -f Red
		}

		$settings.dns_2 = Read-Host "Please provide the secondary DNS-Server"
	}

	Apply-IPconfig $settings
}

function Ask-Name {
	$usr_input = Read-Host "`nPlease provide the full name of the adapter you want to configure"
	try {
		Get-NetAdapter -Name $usr_input -ErrorAction Stop | Out-Null
		return $usr_input
	} catch {
		Write-Host "There is no adapter with the name '$usr_input'" -f Red
		exit
	}
}

function Start-Main {
	param(
		[string[]]$arguments
	)
	if (!(Test-IsAdmin)) {
		Write-Host ("You need administrative priveleges or priveleges " +
					"to configure the network settings to run this script.") -f Red
		return
	}
	Write-Host "`nUse " -NoNewline
	Write-Host "--use_gui" -f Blue -NoNewline
	Write-Host " or " -NoNewline; Write-Host "--open_config" -f Blue -NoNewline
	Write-Host " to set them with a GUI or in the network settings.`n" -NoNewline

	Get-NetAdapter
	Write-Host "`nIf the names are cut of here they are again.`n" -f Green
	(Get-NetAdapter).Name

	$name = Ask-Name

	if ($arguments -match "--use_gui") {
		# set settings via gui
		GUI $name
	} elseif ($arguments -match "--open_config") {
		# Open ncpa.cpl
		Open-Network-Config $name
	} else {
		# set settings via cli
		Use-CLI $name
	}
}

Start-Main $args
