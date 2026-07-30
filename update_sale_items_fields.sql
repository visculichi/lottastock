-- MIGRACIÓN DE SUPABASE: CAMPOS DE DESCUENTO Y ETIQUETA A NIVEL DE ÍTEM (DETALLES DE VENTA)
-- Ejecuta este script en el SQL Editor de tu consola de Supabase

-- 1. Agregar discount_percent a sale_items (porcentaje de descuento aplicado individualmente)
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS discount_percent numeric DEFAULT 0;

-- 2. Agregar ticket_tag_id a sale_items (etiqueta promocional asignada individualmente)
ALTER TABLE sale_items ADD COLUMN IF NOT EXISTS ticket_tag_id uuid REFERENCES ticket_tags(id) ON DELETE SET NULL;
