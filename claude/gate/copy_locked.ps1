$src = 'C:\Users\nullkuhl\AppData\Roaming\MetaQuotes\Terminal\Common\Files\UltTrader_TradeEvents_XAUUSD+_20230101_0000.csv'
$dst = 'C:\Trading\UltimateTrader\claude\gate\tmp_events_2326.csv'
$fs = [System.IO.File]::Open($src, 'Open', 'Read', 'ReadWrite')
$out = [System.IO.File]::Create($dst)
$fs.CopyTo($out)
$fs.Close()
$out.Close()
Write-Host "COPIED $((Get-Item $dst).Length) bytes"
