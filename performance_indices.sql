-- OPTIMIZACIÓN DE RENDIMIENTO: ÍNDICES DE BÚSQUEDA
-- Estos índices aceleran drásticamente los reportes Z, Historial y Consumo.

-- 1. Indexar referencia en movimientos de stock (para cruce con ventas)
CREATE INDEX IF NOT EXISTS idx_stock_movements_ref ON stock_movements(reference_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_type ON stock_movements(movement_type);

-- 2. Indexar items de venta por ticket
CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items(sale_id);

-- 3. Indexar fechas de venta
CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(sale_date);
