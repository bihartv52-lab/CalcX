import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

Deno.serve(async () => {
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  const { data: expired, error } = await supabase
    .from('media')
    .select('id, storage_path')
    .lte('expires_at', new Date().toISOString())
    .limit(500);

  if (error) {
    return Response.json({ error: error.message }, { status: 500 });
  }

  const paths = (expired ?? []).map((item) => item.storage_path);
  if (paths.length > 0) {
    const { error: storageError } = await supabase.storage
      .from('media')
      .remove(paths);

    if (storageError) {
      return Response.json({ error: storageError.message }, { status: 500 });
    }

    await supabase
      .from('media')
      .delete()
      .in(
        'id',
        expired.map((item) => item.id),
      );
  }

  return Response.json({ deleted: paths.length });
});
