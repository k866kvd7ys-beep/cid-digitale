begin;

create or replace function public.update_insurance_claim_details(
  p_claim_id text,
  p_insurance_product text default null,
  p_insurance_type text default null,
  p_coverage text default null,
  p_coverage_modules text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, auth
as $$
declare
  v_claim_json jsonb;
  v_payload jsonb;
  v_liability text;
  v_target_party text;
  v_product text;
  v_type text;
  v_coverage text;
  v_modules text;
  v_paths jsonb;
  v_path_json jsonb;
  v_path text[];
  v_found boolean;
  v_has_product_column boolean;
  v_has_type_column boolean;
  v_has_updated_at_column boolean;
  v_has_updated_by_column boolean;
  v_update_sql text;
begin
  if auth.uid() is null then
    raise exception 'authenticated_insurance_user_required';
  end if;

  if nullif(btrim(coalesce(p_claim_id, '')), '') is null then
    raise exception 'claim_id_required';
  end if;

  select
    to_jsonb(c),
    coalesce(c.payload_json::jsonb, '{}'::jsonb)
  into v_claim_json, v_payload
  from public.claims c
  where c.id::text = btrim(p_claim_id)
  for update;

  if not found then
    raise exception 'claim_not_found';
  end if;

  if not public.is_claim_insurance_editor(btrim(p_claim_id)) then
    raise exception 'insurance_claim_participant_required_for_details_update';
  end if;

  if length(coalesce(p_insurance_product, '')) > 250 then
    raise exception 'insurance_product_too_long';
  end if;
  if length(coalesce(p_insurance_type, '')) > 80 then
    raise exception 'insurance_type_too_long';
  end if;
  if length(coalesce(p_coverage, '')) > 500 then
    raise exception 'insurance_coverage_too_long';
  end if;
  if length(coalesce(p_coverage_modules, '')) > 2000 then
    raise exception 'insurance_coverage_modules_too_long';
  end if;

  v_product := case
    when p_insurance_product is null then null
    else btrim(p_insurance_product)
  end;
  v_type := case
    when p_insurance_type is null then null
    else btrim(p_insurance_type)
  end;
  v_coverage := case
    when p_coverage is null then null
    else btrim(p_coverage)
  end;
  v_modules := case
    when p_coverage_modules is null then null
    else btrim(p_coverage_modules)
  end;

  v_liability := lower(
    regexp_replace(
      coalesce(
        nullif(v_payload ->> 'colpevole', ''),
        nullif(v_payload ->> 'guilty_party', ''),
        nullif(v_payload ->> 'liable_party', ''),
        nullif(v_claim_json ->> 'guilty_party', ''),
        nullif(v_claim_json ->> 'liable_party', ''),
        ''
      ),
      '[^a-z0-9]+',
      '',
      'g'
    )
  );

  v_target_party := case
    when v_liability in (
      'b',
      'conducenteb',
      'driverb',
      'fahrerb',
      'conducteurb',
      'seconddriver',
      'secondofahrer',
      'secondoconducente',
      'counterparty',
      'gegenpartei'
    ) or (
      right(v_liability, 1) = 'b'
      and (
        v_liability like '%conducente%'
        or v_liability like '%driver%'
        or v_liability like '%fahrer%'
        or v_liability like '%conducteur%'
      )
    )
      then 'B'
    else 'A'
  end;

  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'claims'
      and column_name = 'insurance_product'
  ) into v_has_product_column;

  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'claims'
      and column_name = 'insurance_type'
  ) into v_has_type_column;

  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'claims'
      and column_name = 'updated_at'
  ) into v_has_updated_at_column;

  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'claims'
      and column_name = 'updated_by'
  ) into v_has_updated_by_column;

  if p_insurance_product is not null
     and (v_target_party = 'B' or not v_has_product_column) then
    v_paths := case
      when v_target_party = 'B' then
        '[
          ["conducenteB", "insurance_product"],
          ["conducenteB", "insuranceProduct"],
          ["conducenteB", "product"],
          ["driverB", "insurance_product"],
          ["driverB", "insuranceProduct"],
          ["driverB", "product"],
          ["insurance_product_b"],
          ["insuranceProductB"],
          ["prodottoAssicurativoB"]
        ]'::jsonb
      else
        '[
          ["insurance", "insurance_product"],
          ["insurance", "insuranceProduct"],
          ["insurance", "product"],
          ["conducenteA", "insurance_product"],
          ["conducenteA", "insuranceProduct"],
          ["conducenteA", "product"],
          ["driverA", "insurance_product"],
          ["driverA", "insuranceProduct"],
          ["driverA", "product"],
          ["manualCase", "insurance", "insurance_product"],
          ["manualCase", "insurance", "insuranceProduct"],
          ["manualCase", "insurance", "product"],
          ["insurance_product"],
          ["insuranceProduct"],
          ["prodotto_assicurativo"],
          ["versicherungsprodukt"]
        ]'::jsonb
    end;
    v_found := false;
    for v_path_json in
      select value from jsonb_array_elements(v_paths)
    loop
      select array_agg(item order by ordinality)
      into v_path
      from jsonb_array_elements_text(v_path_json)
        with ordinality as path_item(item, ordinality);
      if v_payload #> v_path is not null then
        v_payload := jsonb_set(v_payload, v_path, to_jsonb(v_product), true);
        v_found := true;
      end if;
    end loop;
    if not v_found then
      if v_target_party = 'B' then
        if jsonb_typeof(v_payload -> 'conducenteB') = 'object' then
          v_path := array['conducenteB', 'insurance_product'];
        elsif jsonb_typeof(v_payload -> 'driverB') = 'object' then
          v_path := array['driverB', 'insurance_product'];
        else
          v_payload := jsonb_set(
            v_payload,
            array['conducenteB'],
            '{}'::jsonb,
            true
          );
          v_path := array['conducenteB', 'insurance_product'];
        end if;
      elsif jsonb_typeof(v_payload -> 'insurance') = 'object' then
        v_path := array['insurance', 'insurance_product'];
      else
        v_path := array['insurance_product'];
      end if;
      v_payload := jsonb_set(v_payload, v_path, to_jsonb(v_product), true);
    end if;
  end if;

  if p_insurance_type is not null
     and (v_target_party = 'B' or not v_has_type_column) then
    v_paths := case
      when v_target_party = 'B' then
        '[
          ["conducenteB", "insurance_type"],
          ["conducenteB", "insuranceType"],
          ["conducenteB", "tipoAssicurazione"],
          ["conducenteB", "tipoPolizza"],
          ["driverB", "insurance_type"],
          ["driverB", "insuranceType"],
          ["driverB", "tipoAssicurazione"],
          ["driverB", "tipoPolizza"],
          ["insurance_type_b"],
          ["insuranceTypeB"],
          ["tipoPolizzaB"]
        ]'::jsonb
      else
        '[
          ["insurance", "insurance_type"],
          ["insurance", "insuranceType"],
          ["insurance", "tipoAssicurazione"],
          ["insurance", "tipoPolizza"],
          ["insurance", "versicherungsart"],
          ["conducenteA", "insurance_type"],
          ["conducenteA", "insuranceType"],
          ["driverA", "insurance_type"],
          ["driverA", "insuranceType"],
          ["manualCase", "insurance", "insurance_type"],
          ["manualCase", "insurance", "insuranceType"],
          ["insurance_type"],
          ["insuranceType"],
          ["tipo_assicurazione"],
          ["tipoAssicurazione"],
          ["tipoPolizza"],
          ["versicherungsart"]
        ]'::jsonb
    end;
    v_found := false;
    for v_path_json in
      select value from jsonb_array_elements(v_paths)
    loop
      select array_agg(item order by ordinality)
      into v_path
      from jsonb_array_elements_text(v_path_json)
        with ordinality as path_item(item, ordinality);
      if v_payload #> v_path is not null then
        v_payload := jsonb_set(v_payload, v_path, to_jsonb(v_type), true);
        v_found := true;
      end if;
    end loop;
    if not v_found then
      if v_target_party = 'B' then
        if jsonb_typeof(v_payload -> 'conducenteB') = 'object' then
          v_path := array['conducenteB', 'insurance_type'];
        elsif jsonb_typeof(v_payload -> 'driverB') = 'object' then
          v_path := array['driverB', 'insurance_type'];
        else
          v_payload := jsonb_set(
            v_payload,
            array['conducenteB'],
            '{}'::jsonb,
            true
          );
          v_path := array['conducenteB', 'insurance_type'];
        end if;
      elsif jsonb_typeof(v_payload -> 'insurance') = 'object' then
        v_path := array['insurance', 'insurance_type'];
      else
        v_path := array['insurance_type'];
      end if;
      v_payload := jsonb_set(v_payload, v_path, to_jsonb(v_type), true);
    end if;
  end if;

  if p_coverage is not null then
    v_paths := case
      when v_target_party = 'B' then
        '[
          ["conducenteB", "coverage"],
          ["conducenteB", "coverageType"],
          ["conducenteB", "coverage_type"],
          ["conducenteB", "copertura"],
          ["conducenteB", "deckung"],
          ["driverB", "coverage"],
          ["driverB", "coverageType"],
          ["driverB", "coverage_type"],
          ["driverB", "copertura"],
          ["driverB", "deckung"],
          ["coverage_b"],
          ["coverageB"]
        ]'::jsonb
      else
        '[
          ["coverage"],
          ["coverage_type"],
          ["copertura"],
          ["deckung"],
          ["insurance", "coverage"],
          ["insurance", "coverageType"],
          ["insurance", "coverage_type"],
          ["insurance", "copertura"],
          ["insurance", "deckung"],
          ["conducenteA", "coverage"],
          ["conducenteA", "coverageType"],
          ["conducenteA", "coverage_type"],
          ["conducenteA", "copertura"],
          ["conducenteA", "deckung"],
          ["driverA", "coverage"],
          ["driverA", "coverageType"],
          ["driverA", "coverage_type"],
          ["driverA", "copertura"],
          ["driverA", "deckung"],
          ["manualCase", "insurance", "coverage"]
        ]'::jsonb
    end;
    v_found := false;
    for v_path_json in
      select value from jsonb_array_elements(v_paths)
    loop
      select array_agg(item order by ordinality)
      into v_path
      from jsonb_array_elements_text(v_path_json)
        with ordinality as path_item(item, ordinality);
      if v_payload #> v_path is not null then
        v_payload := jsonb_set(v_payload, v_path, to_jsonb(v_coverage), true);
        v_found := true;
      end if;
    end loop;
    if not v_found then
      if v_target_party = 'B' then
        if jsonb_typeof(v_payload -> 'conducenteB') = 'object' then
          v_path := array['conducenteB', 'coverage'];
        elsif jsonb_typeof(v_payload -> 'driverB') = 'object' then
          v_path := array['driverB', 'coverage'];
        else
          v_payload := jsonb_set(
            v_payload,
            array['conducenteB'],
            '{}'::jsonb,
            true
          );
          v_path := array['conducenteB', 'coverage'];
        end if;
      elsif jsonb_typeof(v_payload -> 'insurance') = 'object' then
        v_path := array['insurance', 'coverage'];
      else
        v_path := array['coverage'];
      end if;
      v_payload := jsonb_set(v_payload, v_path, to_jsonb(v_coverage), true);
    end if;
  end if;

  if p_coverage_modules is not null then
    v_paths := case
      when v_target_party = 'B' then
        '[
          ["conducenteB", "coverage_modules"],
          ["conducenteB", "coverageModules"],
          ["driverB", "coverage_modules"],
          ["driverB", "coverageModules"],
          ["coverage_modules_b"],
          ["coverageModulesB"],
          ["moduliCoperturaB"]
        ]'::jsonb
      else
        '[
          ["coverage_modules"],
          ["coverageModules"],
          ["insurance", "coverage_modules"],
          ["insurance", "coverageModules"],
          ["conducenteA", "coverage_modules"],
          ["conducenteA", "coverageModules"],
          ["driverA", "coverage_modules"],
          ["driverA", "coverageModules"],
          ["manualCase", "insurance", "coverage_modules"],
          ["manualCase", "insurance", "coverageModules"],
          ["manualCase", "extra", "coverageModules"]
        ]'::jsonb
    end;
    v_found := false;
    for v_path_json in
      select value from jsonb_array_elements(v_paths)
    loop
      select array_agg(item order by ordinality)
      into v_path
      from jsonb_array_elements_text(v_path_json)
        with ordinality as path_item(item, ordinality);
      if v_payload #> v_path is not null then
        v_payload := jsonb_set(v_payload, v_path, to_jsonb(v_modules), true);
        v_found := true;
      end if;
    end loop;
    if not v_found then
      if v_target_party = 'B' then
        if jsonb_typeof(v_payload -> 'conducenteB') = 'object' then
          v_path := array['conducenteB', 'coverage_modules'];
        elsif jsonb_typeof(v_payload -> 'driverB') = 'object' then
          v_path := array['driverB', 'coverage_modules'];
        else
          v_payload := jsonb_set(
            v_payload,
            array['conducenteB'],
            '{}'::jsonb,
            true
          );
          v_path := array['conducenteB', 'coverage_modules'];
        end if;
      elsif jsonb_typeof(v_payload -> 'insurance') = 'object' then
        v_path := array['insurance', 'coverage_modules'];
      else
        v_path := array['coverage_modules'];
      end if;
      v_payload := jsonb_set(v_payload, v_path, to_jsonb(v_modules), true);
    end if;
  end if;

  v_update_sql := 'update public.claims set payload_json = $1';
  if v_target_party = 'A'
     and p_insurance_product is not null
     and v_has_product_column then
    v_update_sql := v_update_sql || ', insurance_product = $2';
  end if;
  if v_target_party = 'A'
     and p_insurance_type is not null
     and v_has_type_column then
    v_update_sql := v_update_sql || ', insurance_type = $3';
  end if;
  if v_has_updated_at_column then
    v_update_sql := v_update_sql || ', updated_at = now()';
  end if;
  if v_has_updated_by_column then
    v_update_sql := v_update_sql || ', updated_by = $4';
  end if;
  v_update_sql := v_update_sql || ' where id::text = $5';

  execute v_update_sql
  using v_payload, v_product, v_type, auth.uid(), btrim(p_claim_id);

  return jsonb_build_object(
    'updated', true,
    'claim_id', btrim(p_claim_id),
    'target_party', v_target_party,
    'insurance_product', v_product,
    'insurance_type', v_type,
    'coverage', v_coverage,
    'coverage_modules', v_modules
  );
end;
$$;

revoke all on function public.update_insurance_claim_details(
  text,
  text,
  text,
  text,
  text
) from public;
revoke all on function public.update_insurance_claim_details(
  text,
  text,
  text,
  text,
  text
) from anon;
grant execute on function public.update_insurance_claim_details(
  text,
  text,
  text,
  text,
  text
) to authenticated;

comment on function public.update_insurance_claim_details(
  text,
  text,
  text,
  text,
  text
) is
  'Updates only insurance product, type and coverage for the claim party assigned to the authenticated insurance participant.';

commit;
