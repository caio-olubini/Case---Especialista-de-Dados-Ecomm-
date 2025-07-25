CREATE OR REPLACE PROCEDURE projeto.dataset.proc_cpv_normalizado()
BEGIN
  CREATE OR REPLACE TABLE projeto.dataset.cpv_normalizado AS (
    WITH base_cpv_historico AS (
      SELECT
        SAFE_CAST(ano AS INT64) AS ano,
        UPPER(cod_un_negocio) AS cod_un_negocio,
        LPAD(SAFE_CAST(cod_material AS STRING), 5, '0') AS cod_material,
        SAFE_CAST(cpv AS FLOAT64) AS cpv
      FROM tb_cpv_historico
    ),
    base_cpv_ecomm AS (
      SELECT
        SAFE_CAST(ano AS INT64) AS ano,
        UPPER(cod_un_negocio) AS cod_un_negocio,
        LPAD(SAFE_CAST(cod_material AS STRING), 5, '0') AS cod_material,
        SAFE_CAST(cpv AS FLOAT64) AS cpv
      FROM tb_cpv_ecomm
    ),
    base_cpv_linx AS (
      SELECT
        SAFE_CAST(ano AS INT64) AS ano,
        UPPER(cod_un_negocio) AS cod_un_negocio,
        LPAD(SAFE_CAST(cod_material AS STRING), 5, '0') AS cod_material,
        SAFE_CAST(cpv AS FLOAT64) AS cpv
      FROM tb_cpv_ecomm_linx
    ),
    indices_material_ano AS (
      SELECT ano, cod_un_negocio, cod_material FROM base_cpv_historico
      UNION
      SELECT ano, cod_un_negocio, cod_material FROM base_cpv_ecomm
      UNION
      SELECT ano, cod_un_negocio, cod_material FROM base_cpv_linx
    ),
    base_cpvs_consolidados AS (
      SELECT
        i.ano,
        i.cod_un_negocio,
        i.cod_material,
        COALESCE(b_hist.cpv, b_ecomm.cpv, b_linx.cpv) AS cpv
      FROM indices_material_ano AS i
      LEFT JOIN base_cpv_historico AS b_hist
        ON i.cod_material = b_hist.cod_material AND i.ano = b_hist.ano AND i.cod_un_negocio = b_hist.cod_un_negocio
      LEFT JOIN base_cpv_ecomm AS b_ecomm
        ON i.cod_material = b_ecomm.cod_material AND i.ano = b_ecomm.ano AND i.cod_un_negocio = b_ecomm.cod_un_negocio
      LEFT JOIN base_cpv_linx AS b_linx
        ON i.cod_material = b_linx.cod_material AND i.ano = b_linx.ano AND i.cod_un_negocio = b_linx.cod_un_negocio
    ),
    base_cpv_combos AS (
      SELECT
        combo.cod_material_pai AS cod_material,
        combo.cod_un_negocio,
        SUM(cpvs.cpv) AS cpv
      FROM tb_produto_sku_combo AS combo
      LEFT JOIN base_cpvs_consolidados AS cpvs
        ON combo.cod_un_negocio = cpvs.cod_un_negocio AND combo.cod_material_filho = cpvs.cod_material
      GROUP BY
        1, 2
    )
    SELECT
      cpvs.ano,
      cpvs.cod_un_negocio,
      cpvs.cod_material,
      IF(skus.flg_combo IS TRUE, combo.cpv, cpvs.cpv) AS cpv
    FROM base_cpvs_consolidados AS cpvs
    INNER JOIN tb_produto_skus AS skus
      ON cpvs.cod_un_negocio = skus.cod_un_negocio AND cpvs.cod_material = skus.cod_material
    LEFT JOIN base_cpv_combos AS combo
      ON cpvs.cod_un_negocio = combo.cod_un_negocio AND cpvs.cod_material = combo.cod_material
  );
END;