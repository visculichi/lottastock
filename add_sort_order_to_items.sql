-- MIGRACIÓN DE SUPABASE: ORDEN MANUAL DE PRODUCTOS
-- Ejecuta este script en el SQL Editor de tu consola de Supabase

-- Agregar la columna sort_order a la tabla items
ALTER TABLE items ADD COLUMN IF NOT EXISTS sort_order integer DEFAULT 0;
