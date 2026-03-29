-- ACTUALIZACIÓN DE TABLA DE VENTAS
-- Agrega soporte para fecha de turno y turno (Mañana/Noche)
ALTER TABLE sales ADD COLUMN IF NOT EXISTS sale_date date DEFAULT CURRENT_DATE;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS shift text DEFAULT 'Día';

-- Índices para mejorar la velocidad de reportes
CREATE INDEX IF NOT EXISTS idx_sales_date_shift ON sales(sale_date, shift);
