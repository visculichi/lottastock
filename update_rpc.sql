-- ACTUALIZACIÓN DE MOTOR DE STOCK: DEDUCCIÓN HÍBRIDA (STOCK VS RECETA)
-- Esta función decide si descuenta el producto final o sus ingredientes según disponibilidad.

-- 1. Función auxiliar recursiva para manejar la lógica "Si hay stock descuento eso, sino receta"
CREATE OR REPLACE FUNCTION internal_deduct_item_smart(
  p_item_id uuid,
  p_needed_qty numeric,
  p_deposit_id uuid,
  p_sale_id uuid
) RETURNS void AS $$
DECLARE
  v_current_stock numeric;
  v_has_recipe boolean;
  v_is_production boolean;
  v_yield numeric;
  v_recipe_row RECORD;
BEGIN
  -- 1. Obtener info del item
  SELECT 
    COALESCE(is_production, false), 
    COALESCE(NULLIF(bulk_size, 0), 1) 
  INTO v_is_production, v_yield 
  FROM items WHERE id = p_item_id;

  -- 2. Ver stock actual en el depósito
  SELECT quantity INTO v_current_stock 
  FROM inventory 
  WHERE item_id = p_item_id AND deposit_id = p_deposit_id;
  v_current_stock := COALESCE(v_current_stock, 0);

  -- 3. Ver si tiene receta
  SELECT EXISTS(SELECT 1 FROM recipes WHERE product_id = p_item_id) INTO v_has_recipe;

  -- 4. DECISIÓN DE DEDUCCIÓN:
  -- CASO A: Es un producto "Phantom" (Tiene receta y NO es de producción -> Ej: Salsa, Burger)
  -- CASO B: Es de producción pero NO tenemos stock (Stock <= 0 -> Producido al vuelo)
  IF v_has_recipe AND (NOT v_is_production OR v_current_stock <= 0) THEN
    -- RECURSIÓN: Descomponer en ingredientes
    FOR v_recipe_row IN SELECT ingredient_id, quantity FROM recipes WHERE product_id = p_item_id LOOP
      -- Se descuenta proporcionalmente al rendimiento (bulk_size) del padre
      PERFORM internal_deduct_item_smart(
        v_recipe_row.ingredient_id, 
        (p_needed_qty / v_yield) * v_recipe_row.quantity, 
        p_deposit_id, 
        p_sale_id
      );
    END LOOP;
  
  ELSE
    -- CASO C: Es materia prima pura, o hay stock del producto elaborado, o no tiene receta.
    -- Deducir el item directamente.
    UPDATE inventory 
    SET quantity = quantity - p_needed_qty, updated_at = now()
    WHERE item_id = p_item_id AND deposit_id = p_deposit_id;
    
    IF NOT FOUND THEN
      INSERT INTO inventory (deposit_id, item_id, quantity)
      VALUES (p_deposit_id, p_item_id, -p_needed_qty);
    END IF;

    -- Registrar movimiento histórico para historial y auditoría financiera (CMV)
    INSERT INTO stock_movements (movement_type, item_id, from_deposit_id, to_deposit_id, quantity, reference_id, notes)
    VALUES ('sale_deduction', p_item_id, p_deposit_id, NULL, p_needed_qty, p_sale_id::text, 'Descuento inteligente (Stock vs Receta)');
  END IF;
END;
$$ LANGUAGE plpgsql;

-- 2. Función principal que se llama desde la App al finalizar la venta
CREATE OR REPLACE FUNCTION process_sale_and_deduct_stock(
  p_sale_id uuid,
  p_deposit_id uuid
) RETURNS void AS $$
DECLARE
  sale_item RECORD;
BEGIN
  -- Por cada producto vendido en ese ticket
  FOR sale_item IN SELECT product_id, quantity FROM sale_items WHERE sale_id = p_sale_id LOOP
    -- Ejecutar deducción inteligente
    PERFORM internal_deduct_item_smart(sale_item.product_id, sale_item.quantity, p_deposit_id, p_sale_id);
  END LOOP;
END;
$$ LANGUAGE plpgsql;
