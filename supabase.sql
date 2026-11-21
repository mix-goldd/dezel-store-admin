-- ملاحظة: الملف ده اتشغّل بالفعل على مشروع DEZEL Store. هو للمرجع أو لو أنشأت مشروعًا جديدًا.
-- آمن لو شغّلته قبل كده: بيضيف التصنيفات من غير ما يمسح منتجاتك.

create table if not exists public.admins (email text primary key);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9-]+$'),
  name_en text not null,
  name_ar text not null,
  spec_type text not null default 'details' check (spec_type in ('details','notes')),
  published boolean not null default true,
  sort int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  cat text not null,
  name text not null,
  type_en text not null default '',
  type_ar text not null default '',
  price numeric not null default 0,
  desc_en text not null default '',
  desc_ar text not null default '',
  specs jsonb not null default '[]',
  image_url text,
  published boolean not null default true,
  sort int not null default 0,
  created_at timestamptz not null default now()
);

insert into public.categories (slug, name_en, name_ar, spec_type, sort) values
  ('fragrance', 'Fragrance', 'عطور', 'notes', 0),
  ('watch', 'Watches', 'ساعات', 'details', 1),
  ('case', 'Phone Cases', 'جرابات الهاتف', 'details', 2),
  ('acc', 'Accessories', 'إكسسوارات', 'details', 3)
on conflict (slug) do nothing;

alter table public.products drop constraint if exists products_cat_check;
alter table public.products drop constraint if exists products_cat_fkey;
alter table public.products add constraint products_cat_fkey
  foreign key (cat) references public.categories (slug) on update cascade on delete restrict;

alter table public.admins enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;

drop policy if exists "admin reads own row" on public.admins;
create policy "admin reads own row" on public.admins for select to authenticated
  using (email = auth.jwt() ->> 'email');

drop policy if exists "public reads published categories" on public.categories;
create policy "public reads published categories" on public.categories for select
  using (published = true);
drop policy if exists "admins manage categories" on public.categories;
create policy "admins manage categories" on public.categories for all to authenticated
  using (exists (select 1 from public.admins a where a.email = auth.jwt() ->> 'email')) with check (exists (select 1 from public.admins a where a.email = auth.jwt() ->> 'email'));

drop policy if exists "public reads published products" on public.products;
create policy "public reads published products" on public.products for select
  using (published = true);
drop policy if exists "admins manage products" on public.products;
create policy "admins manage products" on public.products for all to authenticated
  using (exists (select 1 from public.admins a where a.email = auth.jwt() ->> 'email')) with check (exists (select 1 from public.admins a where a.email = auth.jwt() ->> 'email'));

insert into storage.buckets (id, name, public) values ('product-images', 'product-images', true)
  on conflict (id) do nothing;
drop policy if exists "public reads product images" on storage.objects;
-- الـ bucket عام، فالصور بتتعرض من غير سياسة قراءة (وده بيمنع عرض قايمة الملفات)
drop policy if exists "admins manage product images" on storage.objects;
create policy "admins manage product images" on storage.objects for all to authenticated
  using (bucket_id = 'product-images' and exists (select 1 from public.admins a where a.email = auth.jwt() ->> 'email'))
  with check (bucket_id = 'product-images' and exists (select 1 from public.admins a where a.email = auth.jwt() ->> 'email'));

-- غيّر الإيميل ده لإيميلك (نفس إيميل المستخدم اللي هتنشئه في Authentication)
insert into public.admins (email) values ('your-email@example.com') on conflict do nothing;
