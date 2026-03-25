-- ACTUALIZACIÓN DEL MOTOR RECURSIVO PARA SOPORTE DE RINDE / RENDIMIENTO
-- Permite que los productos elaborados (Ej: Bondiola) tengan un rendimiento (Ej: rinden 2000 gramos).
-- Así, si un sandwich usa 200 gramos, el sistema descuenta matemáticamente la proporción correcta (200/2000 = 10% de la receta).

CREATE OR REPLACE FUNCTION process_sale_and_deduct_stock(
  p_sale_id uuid,
  p_deposit_id uuid
) RETURNS void AS $$
DECLARE
  sale_item RECORD;
  recipe_leaf RECORD;
  v_stock_quantity numeric;
BEGIN
  -- Por cada producto vendido en ese ticket
  FOR sale_item IN SELECT product_id, quantity FROM sale_items WHERE sale_id = p_sale_id LOOP
    
    -- Explotar la receta recursivamente para encontrar los insumos base (hojas del arbol)
    FOR recipe_leaf IN 
      WITH RECURSIVE recipe_tree AS (
        -- Caso base: ingredientes directos del producto vendido
        SELECT r.ingredient_id, (r.quantity / COALESCE(NULLIF(i.bulk_size, 0), 1)) as quantity
        FROM recipes r
        JOIN items i ON r.product_id = i.id
        WHERE r.product_id = sale_item.product_id

        UNION ALL

        -- Paso recursivo: ingredientes de los ingredientes (Sub-recetas)
        SELECT r.ingredient_id, (r.quantity / COALESCE(NULLIF(i.bulk_size, 0), 1)) * rt.quantity
        FROM recipes r
        JOIN items i ON r.product_id = i.id
        JOIN recipe_tree rt ON r.product_id = rt.ingredient_id
      )
      -- Quedarnos solo con las "hojas" (materias primas puras que no tienen receta propia)
      SELECT ingredient_id, SUM(quantity) as calc_qty
      FROM recipe_tree
      WHERE ingredient_id NOT IN (SELECT product_id FROM recipes)
      GROUP BY ingredient_id
    LOOP
      
      -- Calcular la cantidad total a deducir de la materia prima pura
      v_stock_quantity := sale_item.quantity * recipe_leaf.calc_qty;
      
      -- 1. Actualizar el inventario real restando la materia prima
      UPDATE inventory 
      SET quantity = quantity - v_stock_quantity, updated_at = now()
      WHERE item_id = recipe_leaf.ingredient_id AND deposit_id = p_deposit_id;
      
      IF NOT FOUND THEN
        INSERT INTO inventory (deposit_id, item_id, quantity)
        VALUES (p_deposit_id, recipe_leaf.ingredient_id, -v_stock_quantity);
      END IF;

      -- 2. Registrar el movimiento histórico para el CMV
      INSERT INTO stock_movements (movement_type, item_id, from_deposit_id, to_deposit_id, quantity, reference_id, notes)
      VALUES ('sale_deduction', recipe_leaf.ingredient_id, p_deposit_id, NULL, v_stock_quantity, p_sale_id::text, 'Descuento recurrente por sub-receta');
      
    END LOOP;
  END LOOP;
END;
$$ LANGUAGE plpgsql;
