-- ACTUALIZACIÓN DE SEGURIDAD PARA EL HISTORIAL DE VENTAS
-- Permite borrar tickets del pasado y restaurar/devolver físicamente
-- todos los gramos y unidades deducidas al inventario.

CREATE OR REPLACE FUNCTION revert_sale_and_restore_stock(
  p_sale_id uuid
) RETURNS void AS $$
DECLARE
  mov RECORD;
BEGIN
  -- 1. Buscar todos los movimientos de stock deducidos asociados a esta venta
  FOR mov IN 
    SELECT item_id, from_deposit_id, quantity 
    FROM stock_movements 
    WHERE reference_id = p_sale_id::text AND movement_type = 'sale_deduction'
  LOOP
    -- 2. Restaurar el inventario (A las bajas se les SUMA de vuelta su cantidad exacta)
    UPDATE inventory 
    SET quantity = quantity + mov.quantity, updated_at = now()
    WHERE item_id = mov.item_id AND deposit_id = mov.from_deposit_id;
  END LOOP;

  -- 3. Borrar el historial de deducciones para no falsear matemáticamente el CMV
  DELETE FROM stock_movements WHERE reference_id = p_sale_id::text;

  -- 4. Borrar la venta en sí misma (Borrará los productos del ticket en cascada)
  DELETE FROM sales WHERE id = p_sale_id;
END;
$$ LANGUAGE plpgsql;
