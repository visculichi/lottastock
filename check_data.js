
const { createClient } = require('@supabase/supabase-js');
const supabaseUrl = 'https://vcswtsisessamawnqanz.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZjc3d0c2lzZXNzYW1hd25xYW56Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzMDQzOTksImV4cCI6MjA4OTg4MDM5OX0.qASSUWcjtc6dhEKN7P-e8Ubnav4enHpvhXT4JKop91Q';
const supabase = createClient(supabaseUrl, supabaseKey);

async function checkData() {
  const { data: sales, count } = await supabase.from('sales').select('id, sale_date', { count: 'exact' }).gte('sale_date', '2026-04-01');
  console.log('Sales in April:', count);
  if (sales && sales.length > 0) {
    const ids = sales.map(s => s.id);
    const { count: itemsCount } = await supabase.from('sale_items').select('id', { count: 'exact' }).in('sale_id', ids);
    console.log('Sale Items for those sales:', itemsCount);
  }
}
checkData();
