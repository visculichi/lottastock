-- Re-creación de la tabla de Mercado para ser más flexible (Carga Manual)
DROP TABLE IF EXISTS market_research;

CREATE TABLE market_research (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  item_id uuid REFERENCES items(id) ON DELETE SET NULL, -- Opcional, si queremos linkear
  product_name text NOT NULL, -- Nombre de MI producto (hamburguesa)
  my_price numeric DEFAULT 0,  -- MI precio Salón
  my_price_platform numeric DEFAULT 0, -- MI precio App
  competitor_name text NOT NULL, -- Nombre de la competencia
  price_store numeric DEFAULT 0, -- Precio Salón competencia
  price_platform numeric DEFAULT 0, -- Precio App competencia
  created_at timestamp with time zone DEFAULT now()
);

CREATE INDEX idx_market_product_name ON market_research(product_name);
