-- Habilitar extensión UUID si no existe
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. DEPOSITOS (Lugares donde se guarda la mercadería)
CREATE TABLE deposits (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

-- 2. ARTICULOS / INSUMOS / PRODUCTOS 
-- (Pueden ser Materia Prima, Productos Ensamblados, o Productos de Venta)
CREATE TABLE items (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  unit text NOT NULL, -- ej: 'kg', 'unidades', 'litros', 'gr'
  type text NOT NULL CHECK (type IN ('raw_material', 'assembled', 'final_product')), 
  cost numeric DEFAULT 0, -- Costo unitario actual
  created_at timestamp with time zone DEFAULT now()
);

-- 3. RECETAS (Escandallos / Composiciones)
-- Define qué ingredientes (y en qué cantidad) componen un producto elaborado
CREATE TABLE recipes (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id uuid REFERENCES items(id) ON DELETE CASCADE,
  ingredient_id uuid REFERENCES items(id) ON DELETE RESTRICT,
  quantity numeric NOT NULL, -- Cantidad del ingrediente necesaria
  UNIQUE(product_id, ingredient_id)
);

-- 4. INVENTARIO ACTUAL
-- Almacena la cantidad exacta que hay de cada item en cada depósito
CREATE TABLE inventory (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  deposit_id uuid REFERENCES deposits(id) ON DELETE CASCADE,
  item_id uuid REFERENCES items(id) ON DELETE CASCADE,
  quantity numeric DEFAULT 0,
  updated_at timestamp with time zone DEFAULT now(),
  UNIQUE(deposit_id, item_id)
);

-- 5. MOVIMIENTOS DE STOCK
-- Historial contable de todo lo que entra y sale para calcular CMV y rastrear pérdidas
CREATE TABLE stock_movements (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  movement_type text NOT NULL CHECK (movement_type IN ('in_purchase', 'out_waste', 'transfer', 'adjustment_initial', 'adjustment_final', 'sale_deduction')),
  item_id uuid REFERENCES items(id) ON DELETE CASCADE,
  from_deposit_id uuid REFERENCES deposits(id), -- Null si es una compra externa o ajuste inicial
  to_deposit_id uuid REFERENCES deposits(id), -- Null si es venta, merma o ajuste final
  quantity numeric NOT NULL, -- Siempre positivo. El flujo lo determina el movement_type
  unit_cost numeric, -- Costo al momento del movimiento (útil para CMV)
  reference_id text, -- ID del ticket, factura o remito asociado
  notes text,
  created_at timestamp with time zone DEFAULT now()
);

-- 6. VENTAS (Tickets)
CREATE TABLE sales (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  ticket_number text,
  total_amount numeric,
  created_at timestamp with time zone DEFAULT now()
);

-- 7. DETALLE DE VENTAS
CREATE TABLE sale_items (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  sale_id uuid REFERENCES sales(id) ON DELETE CASCADE,
  product_id uuid REFERENCES items(id),
  quantity numeric NOT NULL
);

-- 8. FUNCIONES DE BASE DE DATOS (RPC) PARA AUTOMATIZAR DESCUENTOS

-- Función para deducir stock automáticamente usando las recetas cuando se ingresa una venta
CREATE OR REPLACE FUNCTION process_sale_and_deduct_stock(
  p_sale_id uuid,
  p_deposit_id uuid
) RETURNS void AS $$
DECLARE
  sale_item RECORD;
  recipe_item RECORD;
  v_stock_quantity numeric;
BEGIN
  -- Por cada producto vendido en ese ticket
  FOR sale_item IN SELECT product_id, quantity FROM sale_items WHERE sale_id = p_sale_id LOOP
    
    -- Si el producto tiene receta (es elaborado o final)
    FOR recipe_item IN SELECT ingredient_id, quantity FROM recipes WHERE product_id = sale_item.product_id LOOP
      
      -- Calcular la cantidad total a deducir (Cantidad vendida * Cantidad de la receta)
      v_stock_quantity := sale_item.quantity * recipe_item.quantity;
      
      -- 1. Actualizar el inventario real restando
      UPDATE inventory 
      SET quantity = quantity - v_stock_quantity, updated_at = now()
      WHERE item_id = recipe_item.ingredient_id AND deposit_id = p_deposit_id;
      
      -- Si no existía el registro en inventario, se podría manejar creándolo en negativo,
      -- pero idealmente se debería haber cargado stock inicial antes.
      IF NOT FOUND THEN
        INSERT INTO inventory (deposit_id, item_id, quantity)
        VALUES (p_deposit_id, recipe_item.ingredient_id, -v_stock_quantity);
      END IF;

      -- 2. Registrar el movimiento histórico de salida por venta
      INSERT INTO stock_movements (movement_type, item_id, from_deposit_id, to_deposit_id, quantity, reference_id, notes)
      VALUES ('sale_deduction', recipe_item.ingredient_id, p_deposit_id, NULL, v_stock_quantity, p_sale_id::text, 'Descuento automático por receta');
      
    END LOOP;
  END LOOP;
END;
$$ LANGUAGE plpgsql;
