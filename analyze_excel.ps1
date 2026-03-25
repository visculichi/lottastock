$path1 = "c:\Users\Andres\Desktop\STOCK LOTTA\STOCK DIARIO ENERO 2026.xlsx"
$path2 = "c:\Users\Andres\Desktop\STOCK LOTTA\WHOLE LOTTA BURGERS.xlsx"

try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false

    Write-Host "Analyzing: $path1"
    $wb1 = $excel.Workbooks.Open($path1)
    foreach ($sheet in $wb1.Worksheets) {
        Write-Host "  Sheet: $($sheet.Name)"
        $range = $sheet.UsedRange
        Write-Host "    Rows: $($range.Rows.Count), Columns: $($range.Columns.Count)"
        for ($r = 1; $r -le [math]::Min(15, $range.Rows.Count); $r++) {
            $rowStr = "`t"
            for ($c = 1; $c -le [math]::Min(10, $range.Columns.Count); $c++) {
                $cell = $range.Cells.Item($r, $c)
                $val = $cell.Text
                if ($null -eq $val) { $val = "" }
                $rowStr += "$val | "
            }
            Write-Host $rowStr
        }
    }
    $wb1.Close($false)

    Write-Host "`nAnalyzing: $path2"
    $wb2 = $excel.Workbooks.Open($path2)
    foreach ($sheet in $wb2.Worksheets) {
        Write-Host "  Sheet: $($sheet.Name)"
        $range = $sheet.UsedRange
        Write-Host "    Rows: $($range.Rows.Count), Columns: $($range.Columns.Count)"
        for ($r = 1; $r -le [math]::Min(15, $range.Rows.Count); $r++) {
            $rowStr = "`t"
            for ($c = 1; $c -le [math]::Min(10, $range.Columns.Count); $c++) {
                $cell = $range.Cells.Item($r, $c)
                $val = $cell.Text
                if ($null -eq $val) { $val = "" }
                $rowStr += "$val | "
            }
            Write-Host $rowStr
        }
    }
    $wb2.Close($false)

    $excel.Quit()
} catch {
    Write-Host "Error: $_"
} finally {
    if ($excel) {
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
    }
}
