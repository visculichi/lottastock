-- ==========================================
-- ACTUALIZACIÓN DE TABLAS (BULTOS Y PRECIOS)
-- ==========================================
ALTER TABLE items ADD COLUMN IF NOT EXISTS bulk_size numeric DEFAULT 1;
ALTER TABLE items ADD COLUMN IF NOT EXISTS bulk_name text;
ALTER TABLE items ADD COLUMN IF NOT EXISTS sale_price numeric DEFAULT 0;
ALTER TABLE items ADD COLUMN IF NOT EXISTS category text DEFAULT 'General';

-- ==========================================
-- DEPOSITO INICIAL
-- ==========================================
INSERT INTO deposits (id, name) VALUES ('11111111-1111-1111-1111-111111111111', 'Depósito General Principal') ON CONFLICT DO NOTHING;

-- ==========================================
-- CARGA DE INSUMOS BÁSICOS
-- ==========================================
INSERT INTO items (id, name, unit, type, bulk_name, bulk_size) VALUES 
  ('22222222-2222-2222-2222-222222222221', 'Pan TBB', 'unidades', 'raw_material', 'Caja de 90', 90),
  ('22222222-2222-2222-2222-222222222222', 'Medallón 110 gr', 'unidades', 'raw_material', 'Caja de 36', 36),
  ('22222222-2222-2222-2222-222222222223', 'Queso Cheddar', 'gr', 'raw_material', 'Horma 3kg', 3000),
  ('22222222-2222-2222-2222-222222222224', 'Bacon Feteado', 'gr', 'raw_material', 'Paquete 1kg', 1000)
ON CONFLICT DO NOTHING;

-- ==========================================
-- CARGA DE PRODUCTOS ELABORADOS / FINAL
-- ==========================================
INSERT INTO items (id, name, unit, type, bulk_name, bulk_size, category) VALUES 
  ('33333333-3333-3333-3333-333333333331', 'CHEESE BACON BURGER', 'unidades', 'final_product', 'Unidad', 1, 'Hamburguesas'),
  ('33333333-3333-3333-3333-333333333332', 'AMERICAN BURGER', 'unidades', 'final_product', 'Unidad', 1, 'Hamburguesas')
ON CONFLICT DO NOTHING;

-- ==========================================
-- RECETAS / ESCANDALLOS
-- ==========================================
-- Cheese Bacon
INSERT INTO recipes (product_id, ingredient_id, quantity) VALUES 
  ('33333333-3333-3333-3333-333333333331', '22222222-2222-2222-2222-222222222221', 1),
  ('33333333-3333-3333-3333-333333333331', '22222222-2222-2222-2222-222222222222', 2),
  ('33333333-3333-3333-3333-333333333331', '22222222-2222-2222-2222-222222222223', 30),
  ('33333333-3333-3333-3333-333333333331', '22222222-2222-2222-2222-222222222224', 40)
ON CONFLICT DO NOTHING;

-- American
INSERT INTO recipes (product_id, ingredient_id, quantity) VALUES 
  ('33333333-3333-3333-3333-333333333332', '22222222-2222-2222-2222-222222222221', 1),
  ('33333333-3333-3333-3333-333333333332', '22222222-2222-2222-2222-222222222222', 1),
  ('33333333-3333-3333-3333-333333333332', '22222222-2222-2222-2222-222222222223', 15)
ON CONFLICT DO NOTHING;

-- --------------------------------------------------------
-- 4. ACTUALIZACIÓN DEL RPC PARA SUB-RECETAS RECURSIVAS
-- Permite que un elaborado (Ej: Cheese Burger) use otro elaborado (Ej: Medallón)
-- y deduzca automáticamente los insumos primarios al venderse.
-- --------------------------------------------------------
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
        SELECT ingredient_id, quantity
        FROM recipes
        WHERE product_id = sale_item.product_id

        UNION ALL

        -- Paso recursivo: ingredientes de los ingredientes (Sub-recetas)
        SELECT r.ingredient_id, r.quantity * rt.quantity
        FROM recipes r
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

      -- 2. Registrar el movimiento histórico para el CMV exacto
      INSERT INTO stock_movements (movement_type, item_id, from_deposit_id, to_deposit_id, quantity, reference_id, notes)
      VALUES ('sale_deduction', recipe_leaf.ingredient_id, p_deposit_id, NULL, v_stock_quantity, p_sale_id::text, 'Descuento automático recurrente por sub-receta');
      
    END LOOP;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- --------------------------------------------------------
-- 5. PERMISOS DE BORRADO ADMINISTRATIVO (CASCADE)
-- Permite que un admin borre un insumo/producto sin ser bloqueado
-- por el historial de ventas o por pertenecer a otras recetas.
-- --------------------------------------------------------
ALTER TABLE recipes DROP CONSTRAINT IF EXISTS recipes_ingredient_id_fkey;
ALTER TABLE recipes ADD CONSTRAINT recipes_ingredient_id_fkey FOREIGN KEY (ingredient_id) REFERENCES items(id) ON DELETE CASCADE;

ALTER TABLE sale_items DROP CONSTRAINT IF EXISTS sale_items_product_id_fkey;
ALTER TABLE sale_items ADD CONSTRAINT sale_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES items(id) ON DELETE CASCADE;
