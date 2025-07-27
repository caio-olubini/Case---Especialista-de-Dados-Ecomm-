# Changelog de Otimização: tb_estoque_analise_quebra_omni

Este documento descreve as melhorias implementadas na query de criação da tabela `tb_estoque_analise_quebra_omni`, focando nos ganhos de **performance**, **organização** e **legibilidade** do código.

## Resumo das Melhorias

| Categoria | Melhoria Implementada | Impacto |
| :--- | :--- | :--- |
| **Performance** | Filtros de data aplicados no início do processamento. | Redução drástica da quantidade de dados processados nas etapas seguintes. |
| **Performance** | Uso de `QUALIFY` para deduplicação de registros. | Eliminação de subqueries e `GROUP BY` desnecessários, otimizando a execução. |
| **Performance** | Substituição de `UNION ALL` + `NOT EXISTS` por `QUALIFY`. | Lógica de deduplicação mais limpa e performática. |
| **Performance** | Uso de `INNER JOIN` em vez de `LEFT JOIN` com filtro `IS NOT NULL`. | Torna a intenção da junção explícita e permite melhor otimização pelo BigQuery. |
| **Organização** | Estrutura de CTEs linear e simplificada. | Eliminação de CTEs aninhadas, facilitando o fluxo de leitura e manutenção. |
| **Organização** | Uso de `CREATE OR REPLACE TABLE`. | Operação atômica e mais segura que `DROP` + `CREATE`. |
| **Legibilidade** | Uso de funções modernas como `GREATEST()`. | Código mais conciso e expressivo. |
| **Legibilidade** | Formatação e nomenclatura aprimoradas. | Código mais claro, com aliases consistentes e indentação adequada. |

---

## Análise Detalhada das Melhorias

### 1. Performance

#### 1.1. Filtragem Antecipada de Dados
- **Código Antigo**: Os filtros de data (`BETWEEN DT_INICIO AND DT_FIM`) eram aplicados quase no final do processo, nas CTEs `ESTOQUE_BOT` e `ESTOQUE_QDB`. Isso fazia com que as junções e agregações anteriores processassem um volume de dados muito maior que o necessário.
- **Código Novo**: Os filtros de data foram movidos para o início da query, diretamente nas primeiras CTEs (`lista_skus` e `pedidos`).

```sql
-- Código Novo: Filtro aplicado na primeira leitura da tabela
...
FROM tb_omni_pedido_item
WHERE 1 = 1
  AND DATE(dt_hr_atualizacao) BETWEEN DT_INICIO AND DT_FIM -- << MELHORIA
...
````

**Benefício**: Reduz significativamente a quantidade de dados trafegados e processados nas etapas subsequentes, resultando em menor custo e maior velocidade.

#### 1.2. Deduplicação com QUALIFY

  - **Código Antigo**: Para deduplicar os itens de pedido, foi usada uma subquery (`PEDIDO_ITEM`) com `GROUP BY` e `ROW_NUMBER()`, o que é verboso e menos otimizado.
  - **Código Novo**: A cláusula `QUALIFY` foi utilizada para filtrar o resultado da função de janela `ROW_NUMBER()` diretamente, de forma mais limpa e performática.

<!-- end list -->

```sql
-- Código Novo: Uso de QUALIFY para deduplicação eficiente
...
FROM tb_omni_pedido_item
...
QUALIFY ROW_NUMBER() OVER (PARTITION BY cod_pedido, cod_pedido_item, CAST(vlr_receita_item AS STRING) ORDER BY qt_item DESC) = 1 -- << MELHORIA
```

**Benefício**: O BigQuery otimiza a cláusula `QUALIFY` de forma mais eficaz que uma subquery com a mesma lógica, simplificando o plano de execução.

#### 1.3. Substituição de LEFT JOIN por INNER JOIN

  - **Código Antigo**: Utilizava-se `LEFT JOIN` entre as tabelas de estoque e a CTE `PEDIDO`, para depois filtrar os resultados com `WHERE cod_pedido_item IS NOT NULL`.
  - **Código Novo**: A junção foi alterada para `INNER JOIN`.

<!-- end list -->

```sql
-- Código Novo: Junção explícita que melhora a otimização
...
FROM tb_estoque_pdv est
INNER JOIN pedidos ped -- << MELHORIA
  ON ped.cod_pedido_item = est.cod_material
...
```

**Benefício**: Um `INNER JOIN` comunica diretamente ao motor do BigQuery a intenção de manter apenas os registros que existem em ambas as tabelas. Isso permite que o otimizador escolha planos de execução mais eficientes, como reordenar as junções.

#### 1.4. Deduplicação Eficiente entre Fontes de Estoque

  - **Código Antigo**: A união dos estoques BOT e QDB era feita com `UNION ALL`, e a deduplicação ocorria através de uma subquery com `NOT EXISTS`, uma operação complexa e potencialmente lenta.
  - **Código Novo**: As fontes foram unidas com `UNION ALL` adicionando uma coluna `origem`. A deduplicação é feita em uma etapa final com `QUALIFY ROW_NUMBER()`, priorizando a origem 'BOT' de forma explícita e performática.

<!-- end list -->

```sql
-- Código Novo: Lógica de deduplicação clara e otimizada
...
FROM estoque_consolidado
QUALIFY ROW_NUMBER() OVER (PARTITION BY cod_material, dt_estoque, cod_franquia, cod_un_negocio ORDER BY origem) = 1 -- << MELHORIA
```

**Benefício**: A lógica se torna mais legível e o método de partição com `QUALIFY` é mais eficiente para o BigQuery processar do que o `NOT EXISTS`.

### 2\. Organização

#### 2.1. Estrutura de CTEs e Comando DDL

  - **Código Antigo**: Possuía CTEs aninhadas (`PEDIDO_ITEM` dentro de `TEMP_SKU`) e usava dois comandos (`DROP TABLE` e `CREATE TABLE`), o que não é uma operação atômica.
  - **Código Novo**: Todas as CTEs estão em um nível linear, facilitando a leitura sequencial da lógica. O comando `CREATE OR REPLACE TABLE` é utilizado para garantir a atomicidade da operação.

**Código Antigo**

```sql
DROP TABLE IF EXISTS tb_estoque_analise_quebra_omni;
CREATE TABLE tb_estoque_analise_quebra_omni as(
  WITH TEMP_SKU AS (
    WITH PEDIDO_ITEM AS (...)
    ...
  )
  ...
)
```

**Código Novo**

```sql
CREATE OR REPLACE TABLE tb_estoque_analise_quebra_omni AS ( -- << MELHORIA
  WITH lista_skus AS (...), -- << MELHORIA
  pedidos AS (...),
  ...
)
```

**Benefício**: O código fica mais fácil de manter e depurar. O uso de `CREATE OR REPLACE` é mais seguro e eficiente, evitando estados em que a tabela não existe.

### 3\. Legibilidade

#### 3.1. Sintaxe Moderna e Concisa

  - **Código Antigo**: Utilizava construções como `IF(qt_item = 0, 1, qt_item)` e declarações de variáveis em duas linhas.
  - **Código Novo**: Adota funções mais expressivas como `GREATEST(qt_item, 1)` e a declaração de variáveis com valor `DEFAULT` em uma única linha.

**Antigo**

```sql
IF(qt_item = 0, 1, qt_item)
```

**Novo**

```sql
GREATEST(qt_item, 1) -- << MELHORIA
```

**Benefício**: O código se torna mais enxuto, autoexplicativo e alinhado com as práticas modernas de SQL.

#### 3.2. Formatação e Nomenclatura

  - **Código Antigo**: A indentação e o uso de aliases eram inconsistentes.
  - **Código Novo**: Apresenta uma indentação clara que destaca a estrutura do código (cláusulas `FROM`, `JOIN`, `WHERE`). Os aliases são curtos e consistentes (`ped`, `sku`, `mat`, `est`), melhorando a clareza das colunas selecionadas e das condições de junção.

**Benefício**: Um código bem formatado é fundamental para a manutenção a longo prazo e para a colaboração em equipe.

```
```