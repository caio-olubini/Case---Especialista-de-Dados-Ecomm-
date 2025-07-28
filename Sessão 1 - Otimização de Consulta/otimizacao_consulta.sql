DECLARE dt_inicio DATE DEFAULT '2021-11-15';
DECLARE dt_fim DATE DEFAULT CURRENT_DATE();

CREATE OR REPLACE TABLE tb_estoque_analise_quebra_omni AS (
  WITH lista_skus AS (
    SELECT
      cod_pedido,
      cod_pedido_item,
      GREATEST(qt_item, 1) * vlr_receita_item AS vlr_receita_item,
    FROM tb_omni_pedido_item
    WHERE 1 = 1
      AND DATE(dt_hr_atualizacao) BETWEEN DT_INICIO AND DT_FIM
    QUALIFY ROW_NUMBER() OVER (PARTITION BY cod_pedido, cod_pedido_item, CAST(vlr_receita_item AS STRING) ORDER BY qt_item DESC) = 1
  ),
  
  pedidos AS (
    SELECT DISTINCT
      ped.cod_location,
      sku.cod_pedido_item,
      mat.cod_un_material
    FROM tb_pedido_sku ped
    LEFT JOIN lista_skus sku 
      ON CONCAT(ped.cod_pedido, ped.cod_un_negocio_venda) = sku.cod_pedido
    LEFT JOIN tb_material mat 
      ON sku.cod_pedido_item = mat.cod_material
      AND mat.flg_un_original IS TRUE
    WHERE 1 = 1
      AND ped.flg_quebra = 1
      AND ped.dt_venda BETWEEN DT_INICIO AND DT_FIM
  ),

  estoque_consolidado AS (
    SELECT
      '1. BOT' AS origem,
      est.cod_un_negocio,
      est.des_un_negocio,
      est.cod_franquia,
      est.cod_material,
      est.dt_estoque,
      est.qt_estoque_fisico,
      est.qt_estoque_disponivel
    FROM tb_estoque_pdv est
    INNER JOIN pedidos ped 
      ON ped.cod_pedido_item = est.cod_material
      AND SAFE_CAST(ped.cod_location AS INT) = SAFE_CAST(est.cod_franquia AS INT)
      AND ped.cod_un_material = est.cod_un_negocio
    WHERE 1 = 1
      AND DATE(est.dt_estoque) BETWEEN DT_INICIO AND DT_FIM
      AND est.cod_un_negocio NOT IN ('EUD')

    UNION ALL

    SELECT
      '2. QDB' AS origem,
      'QDB' AS cod_un_negocio,
      'QUEM DISSE BERENICE' AS des_un_negocio,
      cod_franquia,
      cod_material,
      dt_carga_estoque AS dt_estoque,
      SAFE_CAST(SUM(qt_estoque / 1000) AS INT) AS qt_estoque_fisico,
      SAFE_CAST(SUM(qt_estoque / 1000) AS INT) AS qt_estoque_disponivel
    FROM tb_estoque_qdb_pdv est
    INNER JOIN pedidos ped 
      ON ped.cod_pedido_item = est.cod_material
      AND SAFE_CAST(ped.cod_location AS INT) = SAFE_CAST(est.cod_franquia AS INT)
    WHERE 1 = 1
      AND DATE(dt_carga_estoque) BETWEEN dt_inicio AND dt_fim
    GROUP BY ALL

  ),
  
  estoque_deduplicado AS (
    SELECT
      origem,
      cod_un_negocio,
      des_un_negocio,
      cod_franquia,
      cod_material,
      dt_estoque,
      qt_estoque_fisico,
      qt_estoque_disponivel
    FROM estoque_consolidado
    QUALIFY ROW_NUMBER() OVER (PARTITION BY cod_material, dt_estoque, cod_franquia, cod_un_negocio ORDER BY origem) = 1 -- Priorizando estoque BOT
  )

  SELECT
    cod_un_negocio,
    des_un_negocio,
    cod_franquia,
    cod_material,
    dt_estoque,
    qt_estoque_fisico,
    qt_estoque_disponivel,
    LAST_VALUE(IF(qt_estoque_disponivel > 0, dt_estoque, NULL) IGNORE NULLS) OVER (
      PARTITION BY cod_franquia, cod_material
      ORDER BY dt_estoque ASC
      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
    ) AS dt_ultimo_dia_estoque_positivo
  FROM estoque_deduplicado
);
