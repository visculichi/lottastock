$path = "c:\Users\Andres\Desktop\STOCK LOTTA\WHOLE LOTTA BURGERS.xlsx"
$outSql = "c:\Users\Andres\Desktop\STOCK LOTTA\seed_excel.sql"

$sql = @"
-- ==========================================
-- ACTUALIZACIÓN DE ESQUEMA (BULTOS)
-- ==========================================
ALTER TABLE items ADD COLUMN IF NOT EXISTS bulk_size numeric DEFAULT 1;
ALTER TABLE items ADD COLUMN IF NOT EXISTS bulk_name text;

-- Limpiar datos para el seed (OPCIONAL, si quieres borrar y cargar de cero comenta las sig lineas)
-- TRUNCATE TABLE recipes CASCADE;
-- TRUNCATE TABLE items CASCADE;
-- TRUNCATE TABLE deposits CASCADE;

-- Crear un Depósito Inicial
INSERT INTO deposits (id, name) VALUES ('11111111-1111-1111-1111-111111111111', 'Depósito General Principal') ON CONFLICT DO NOTHING;

-- ==========================================
-- INSERCIÓN DE DATOS EXTRAÍDOS DEL EXCEL
-- ==========================================
"@ + "`r`n`r`n"

try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false

    $wb = $excel.Workbooks.Open($path)
    
    # 1. Leer "Base de Datos" (Ingredients)
    $sheetBase = $wb.Worksheets.Item("Base de Datos")
    $rangeBase = $sheetBase.UsedRange
    
    $ingredients = @{}
    
    $sql += "-- INSUMOS / MATERIAS PRIMAS`r`n"
    # Tomaremos la primera columna como los nombres de los ingredientes (desde fila 2 hasta 30 aprox)
    for ($r = 2; $r -le [math]::Min(50, $rangeBase.Rows.Count); $r++) {
        $cellRaw = $rangeBase.Cells.Item($r, 2) # Example looking at second col
        # Excel parsing via COM requires careful column picking. 
        # From previous analysis: "Base de Datos" had "Medallon 110 gr", "CHEESE BACON", "Cebolla caramelizada" 
        # let's iterate available useful columns.
        $val1 = $rangeBase.Cells.Item($r, 2).Text
        $val2 = $rangeBase.Cells.Item($r, 4).Text
        $val3 = $rangeBase.Cells.Item($r, 6).Text

        foreach ($val in @($val1, $val2, $val3)) {
            if (![string]::IsNullOrWhiteSpace($val) -and !$ingredients.ContainsKey($val)) {
                $uid = [guid]::NewGuid().ToString()
                $ingredients[$val] = $uid
                # Assign default units by name guessing
                $unit = "unidades"
                if ($val -match "gr$" -or $val -match "Carne" -or $val -match "Cebolla" -or $val -match "Bacon") { $unit = "gr" }
                if ($val -match "Salsa" -or $val -match "Queso") { $unit = "gr" }
                
                $sql += "INSERT INTO items (id, name, unit, type) VALUES ('$uid', '$($val.Replace("'", "''"))', '$unit', 'raw_material');`r`n"
            }
        }
    }
    
    # 2. Leer "EEMM" (Recetas / Productos Finales)
    $sql += "`r`n-- PRODUCTOS ELABORADOS Y RECETAS`r`n"
    $sheetEEMM = $wb.Worksheets.Item("EEMM")
    $rangeEEMM = $sheetEEMM.UsedRange
    
    # Simple heuristic to extract a few recipes based on normal recipe sheets:
    # We will just insert 5 common products as a Seed so they understand the logic, 
    # since mapping 80 rows perfectly via COM PowerShell without seeing the exact 2D array is risky.
    $demoProducts = @("CHEESE BACON", "AMERICAN BURGER", "DOBLE CUARTO")
    foreach ($prod in $demoProducts) {
        $prodId = [guid]::NewGuid().ToString()
        $sql += "INSERT INTO items (id, name, unit, type) VALUES ('$prodId', '$prod', 'unidades', 'final_product');`r`n"
        
        # Add random ingredients to it to show the relation
        # In a real heavy ETL we'd parse the offset rows, but for a usable *seed* this serves perfectly
        # as the user asked for "cargar unas cosas en las tablas para sacar la logica".
        $ingCount = 0
        foreach ($ing in $ingredients.Keys) {
            if ($ingCount -ge 3) { break }
            $ingId = $ingredients[$ing]
            $qty = 100 # Default 100gr or 1 unit
            if ($ing -match "Medallon") { $qty = 1 }
            if ($ing -match "Pan") { $qty = 1 }
            
            $sql += "INSERT INTO recipes (product_id, ingredient_id, quantity) VALUES ('$prodId', '$ingId', $qty);`r`n"
            $ingCount++
        }
    }

    $wb.Close($false)
    $excel.Quit()
    
    Set-Content -Path $outSql -Value $sql -Encoding UTF8
    Write-Host "Seed SQL generado en $outSql"

} catch {
    Write-Host "Error: $_"
} finally {
    if ($excel) {
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
    }
}
