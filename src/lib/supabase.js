import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('缺少环境变量：请复制 .env.example 为 .env，填入 Supabase URL 和 anon key')
}

export const supabase = createClient(supabaseUrl || 'http://placeholder', supabaseAnonKey || 'placeholder')