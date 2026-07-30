-- MIGRACIÓN DE SUPABASE: ETIQUETAS A NIVEL DE TICKET (VENTAS)
-- Ejecuta este script en el SQL Editor de tu consola de Supabase

-- 1. Revertir columnas de items del diseño anterior
ALTER TABLE items DROP COLUMN IF EXISTS tag_name;
ALTER TABLE items DROP COLUMN IF EXISTS tag_color;

-- 2. Crear tabla para etiquetas de tickets si no existe
CREATE TABLE IF NOT EXISTS ticket_tags (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  color text NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

-- Desactivar Seguridad de Fila (RLS) para permitir lectura y escritura desde la aplicación
ALTER TABLE ticket_tags DISABLE ROW LEVEL SECURITY;

-- 3. Vincular la etiqueta a la tabla de ventas (sales)
ALTER TABLE sales ADD COLUMN IF NOT EXISTS ticket_tag_id uuid REFERENCES ticket_tags(id) ON DELETE SET NULL;
