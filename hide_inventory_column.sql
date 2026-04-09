-- MIGRACIÓN: AGREGAR CAMPO PARA OCULTAR DEL INVENTARIO
ALTER TABLE items ADD COLUMN IF NOT EXISTS hide_in_inventory BOOLEAN DEFAULT false;
UPDATE items SET hide_in_inventory = false WHERE hide_in_inventory IS NULL;
