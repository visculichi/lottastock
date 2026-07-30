-- SCRIPT DE MIGRACIÓN: ETIQUETAS Y DESCUENTOS
-- Ejecuta este script en el SQL Editor de tu consola de Supabase

-- 1. Agregar columnas para etiquetas promocionales en la tabla de productos (items)
ALTER TABLE items ADD COLUMN IF NOT EXISTS tag_name text DEFAULT NULL;
ALTER TABLE items ADD COLUMN IF NOT EXISTS tag_color text DEFAULT NULL;

-- 2. Agregar columnas para descuentos y subtotales en la tabla de ventas (sales)
ALTER TABLE sales ADD COLUMN IF NOT EXISTS subtotal_amount numeric DEFAULT 0;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS discount_type text DEFAULT 'Ninguno';
ALTER TABLE sales ADD COLUMN IF NOT EXISTS discount_amount numeric DEFAULT 0;
