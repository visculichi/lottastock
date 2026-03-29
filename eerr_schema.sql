-- EERR: ESTADO DE RESULTADOS (PL) - ESQUEMA OFICIAL
-- Permite el seguimiento de la rentabilidad real cruzando Ventas (Reporte Z) vs Insumos vs Gastos.

-- 1. Tabla de Gastos (Operativos, Fijos y Variables)
CREATE TABLE IF NOT EXISTS expenses (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  description text NOT NULL,
  category text NOT NULL, -- Ej: 'Alquiler', 'Sueldos', 'Servicios', etc.
  amount numeric NOT NULL DEFAULT 0,
  expense_date date NOT NULL DEFAULT CURRENT_DATE,
  created_at timestamp with time zone DEFAULT now()
);

-- Índices para búsqueda por mes
CREATE INDEX IF NOT EXISTS idx_expenses_date_lookup ON expenses(expense_date);

-- 2. Tabla de Metas y Escenarios (Para persistir CMV deseado por mes)
CREATE TABLE IF NOT EXISTS monthly_targets (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  month_year text UNIQUE NOT NULL, -- Formato 'YYYY-MM'
  target_cmv_perc numeric DEFAULT 35,
  created_at timestamp with time zone DEFAULT now()
);
