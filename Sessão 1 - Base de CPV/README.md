# Processo de Consolidação e Normalização de CPV (Custo do Produto Vendido)

Este documento detalha o processo de criação da tabela `projeto.dataset.cpv_normalizado`, que centraliza e trata os dados de Custo do Produto Vendido (CPV) de múltiplas fontes, garantindo um valor único e confiável por produto, unidade de negócio e ano.

---

## O que a Tabela Final Faz?

A tabela **`cpv_normalizado`** serve como a **fonte única da verdade (Single Source of Truth)** para o Custo do Produto Vendido. Ela resolve os seguintes problemas:

-   **Consolidação de Dados**: Unifica o CPV de três sistemas diferentes (`Histórico`, `E-commerce` e `Linx`).
-   **Tratamento de Duplicidade**: Garante que exista apenas um valor de CPV por produto, por ano e por unidade de negócio, utilizando o menor valor (`MIN`) como critério.
-   **Cálculo de Combos**: Calcula corretamente o CPV de produtos do tipo "combo" (ou "kit"), somando os custos de seus componentes individuais.
-   **Padronização**: Normaliza os campos-chave (como `cod_material` e `cod_un_negocio`) para garantir consistência e facilitar os `JOIN`s com outras tabelas.
-   **Monitoramento**: Adiciona um flag (`flg_combo_incompleto`) que sinaliza problemas de qualidade de dados nos combos.

---

## Diagrama de Relacionamento de Dados

O diagrama abaixo ilustra o fluxo de dados, desde as tabelas de origem até a tabela final consolidada.

```mermaid
graph TD
    subgraph Fontes de Dados
        A[tb_cpv_historico]
        B[tb_cpv_ecomm]
        C[tb_cpv_ecomm_linx]
        D[tb_produto_sku_combo]
        E[tb_produto_skus]
    end

    subgraph Tratamento e Agregação (CTEs)
        F[base_cpv_historico]
        G[base_cpv_ecomm]
        H[base_cpv_linx]
        I[indices_material_ano]
        J[base_cpvs_consolidados]
        K[base_cpv_combos]
    end

    subgraph Tabela Final
        L(cpv_normalizado)
    end

    A --> F
    B --> G
    C --> H

    F --> I
    G --> I
    H --> I

    I --> J
    F --> J
    G --> J
    H --> J

    D --> K
    J --> K

    J --> L
    K --> L
    E --> L

    style A fill:#cde4ff,stroke:#6a8ebf
    style B fill:#cde4ff,stroke:#6a8ebf
    style C fill:#cde4ff,stroke:#6a8ebf
    style D fill:#cde4ff,stroke:#6a8ebf
    style E fill:#cde4ff,stroke:#6a8ebf
    style L fill:#d5e8d4,stroke:#82b366
Funcionamento do CódigoO processo é executado através de uma PROCEDURE que utiliza múltiplas Common Table Expressions (CTEs) para construir o resultado passo a passo.Leitura e Limpeza das Fontes (base_cpv_historico, base_cpv_ecomm, base_cpv_linx):Cada uma dessas CTEs lê dados de uma tabela de origem.Realiza a padronização dos dados: converte o ano para INT64, o código da unidade de negócio para maiúsculas (UPPER), e o código do material para STRING com preenchimento de zeros à esquerda (LPAD).Agrupa os dados por ano, unidade de negócio e material, utilizando MIN(cpv) para obter um valor único e evitar duplicidades na origem.Criação de um Índice Mestre (indices_material_ano):Esta CTE utiliza UNION para criar uma lista única de todas as combinações de (ano, cod_un_negocio, cod_material) existentes nas três fontes de dados. Este índice serve como base para a consolidação.Consolidação do CPV (base_cpvs_consolidados):Usa o índice mestre (indices_material_ano) como tabela principal (LEFT JOIN).Junta os dados das três CTEs de base (base_cpv_historico, etc.).A função COALESCE(b_hist.cpv, b_ecomm.cpv, b_linx.cpv) é usada para selecionar o primeiro valor de CPV não nulo encontrado, estabelecendo uma ordem de prioridade entre as fontes.Cálculo do CPV para Combos (base_cpv_combos):Primeiro, a CTE aux_contagem_skus_combo conta quantos itens compõem cada combo.A CTE base_cpv_combos então:Busca a relação de itens "filho" para cada combo "pai" na tabela tb_produto_sku_combo.Junta com os CPVs já consolidados (base_cpvs_consolidados) para encontrar o custo de cada item "filho".Soma (SUM) os CPVs dos filhos para obter o CPV total do combo.Cria o flag flg_combo_incompleto: se a contagem de filhos com CPV encontrado for diferente da quantidade total de filhos que o combo deveria ter, o flag é 1 (verdadeiro), indicando um problema.Geração da Tabela Final (SELECT principal):Junta os CPVs consolidados (base_cpvs_consolidados) com a tabela de produtos (tb_produto_skus) para identificar quais materiais são combos.Faz um LEFT JOIN com os CPVs calculados para os combos (base_cpv_combos).Usa uma instrução IF para decidir qual CPV usar: se flg_combo for verdadeiro, usa o combo.cpv; caso contrário, usa o cpvs.cpv do produto individual.Traz a coluna flg_combo_incompleto para a tabela final.Proposta de Validações e Alertas de MonitoramentoPara garantir a qualidade e a integridade dos dados na tabela final, sugere-se a criação dos seguintes alertas de monitoramento. Essas queries podem ser executadas periodicamente.1. Alerta: CPV NuloVerifica se algum produto ficou sem valor de CPV após a consolidação. Isso nunca deveria acontecer.SELECT COUNT(*) AS qtd_cpv_nulo
FROM projeto.dataset.cpv_normalizado
WHERE cpv IS NULL;
-- O resultado esperado é 0.
2. Alerta: CPV Negativo ou ZeroCusto de produto não pode ser zero ou negativo. Isso indica um erro grave na fonte.SELECT COUNT(*) AS qtd_cpv_invalido
FROM projeto.dataset.cpv_normalizado
WHERE cpv <= 0;
-- O resultado esperado é 0.
3. Alerta: Combos com Cálculo IncompletoMonitora o flag flg_combo_incompleto. Um valor maior que zero indica que o CPV de alguns combos foi calculado sem todos os seus componentes, resultando em um custo subestimado.SELECT SUM(flg_combo_incompleto) AS qtd_combos_incompletos
FROM projeto.dataset.cpv_normalizado;
-- O resultado esperado é 0.
4. Alerta: Variação Anormal de CPVCompara o CPV de um mesmo produto entre anos consecutivos. Uma variação muito grande (ex: mais de 50%) pode indicar um erro de digitação ou de processo na fonte.WITH cpv_com_ano_anterior AS (
  SELECT
    ano,
    cod_material,
    cod_un_negocio,
    cpv,
    LAG(cpv, 1) OVER (PARTITION BY cod_material, cod_un_negocio ORDER BY ano) AS cpv_ano_anterior
  FROM projeto.dataset.cpv_normalizado
)
SELECT
  ano,
  cod_material,
  cod_un_negocio,
  cpv,
  cpv_ano_anterior
FROM cpv_com_ano_anterior
WHERE cpv_ano_anterior > 0
  AND ABS(cpv / cpv_ano_anterior - 1) > 0.5; -- Variação > 50%
-- Espera-se que esta query retorne poucas ou nenhuma linha.
5. Alerta: Material sem CadastroVerifica se existe algum cod_material na tabela de CPV que não está presente na tabela mestre de produtos.SELECT
  cpv.cod_material
FROM projeto.dataset.cpv_normalizado AS cpv
LEFT JOIN tb_produto_skus AS skus
  ON cpv.cod_material = skus.cod_material
  AND cpv.cod_un_negocio = skus.cod_un_negocio
WHERE skus.cod_material IS NULL
GROUP BY 1;
-- O resultado esperado é nenhuma linha.
