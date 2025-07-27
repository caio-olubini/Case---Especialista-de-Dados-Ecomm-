Claro, aqui está uma proposta de arquivo `README.md` para a sua tabela, incluindo a explicação do código, o diagrama de relacionamento e sugestões de validações para monitoramento.

-----

# Tabela `cpv_normalizado`

Este documento detalha a estrutura e o propósito da tabela `projeto.dataset.cpv_normalizado`, gerada pela procedure `proc_cpv_normalizado`. O objetivo principal é consolidar e tratar os dados de Custo de Produto Vendido (CPV) de múltiplas fontes, criando uma base de dados unificada e confiável para análises.


## ⚙️ Funcionamento do Código

A procedure `proc_cpv_normalizado` constrói a tabela final em etapas lógicas, utilizando uma série de Common Table Expressions (CTEs).

1.  **Leitura e Normalização das Fontes (`base_cpv_historico`, `base_cpv_ecomm`, `base_cpv_linx`)**

      * Cada uma dessas CTEs lê dados de uma tabela de origem de CPV.
      * Realiza um tratamento inicial nos dados: converte tipos (`SAFE_CAST`), padroniza o código do material para 5 dígitos com zeros à esquerda (`LPAD`) e transforma o código da unidade de negócio para maiúsculas (`UPPER`).
      * Agrupa os dados por `ano`, `cod_un_negocio` e `cod_material` para obter o **menor CPV (`MIN`)** registrado para cada produto em cada ano, evitando duplicidades dentro da mesma fonte.

2.  **Criação do Índice Mestre (`indices_material_ano`)**

      * Esta CTE une as chaves (`ano`, `cod_un_negocio`, `cod_material`) de todas as fontes de CPV.
      * Seu objetivo é criar um conjunto único de todos os produtos que já tiveram um CPV registrado em qualquer uma das fontes, garantindo que nenhum produto seja perdido durante a consolidação.

3.  **Consolidação dos CPVs (`base_cpvs_consolidados`)**

      * Utiliza o índice mestre como base e faz um `LEFT JOIN` com cada uma das três CTEs de fonte.
      * Usa a função `COALESCE(b_hist.cpv, b_ecomm.cpv, b_linx.cpv)` para preencher o valor de CPV, estabelecendo uma **ordem de prioridade**:
        1.  `tb_cpv_historico`
        2.  `tb_cpv_ecomm`
        3.  `tb_cpv_ecomm_linx`
      * O resultado é uma base com o CPV de produtos simples, já consolidado.

4.  **Cálculo do CPV de Combos (`base_cpv_combos`)**

      * Esta CTE é responsável por calcular o CPV de produtos que são "combos" (compostos por outros produtos).
      * Ela soma (`SUM`) o CPV dos "produtos filhos" que compõem cada "produto pai" (o combo).
      * Além disso, cria a flag `flg_combo_incompleto`: se a quantidade de filhos com CPV encontrado for diferente da quantidade total de filhos que o combo deveria ter, a flag é marcada como `1`. Isso indica um possível problema no cálculo do CPV do combo.

5.  **Seleção e Junção Final**

      * A query final une a base de CPVs consolidados (`base_cpvs_consolidados`) com a de produtos (`tb_produto_skus`) e a de CPVs de combos (`base_cpv_combos`).
      * Utiliza a coluna `skus.flg_combo` para decidir qual CPV usar:
          * Se `flg_combo` for `TRUE`, utiliza o CPV calculado na CTE `base_cpv_combos`.
          * Caso contrário, utiliza o CPV da `base_cpvs_consolidados`.
      * O resultado é a tabela `cpv_normalizado`, contendo o CPV para todos os produtos (simples e combos) e a flag de monitoramento para combos incompletos.

-----

## 📊 Validações e Alertas de Monitoramento

Para garantir a qualidade e a confiabilidade dos dados na tabela `cpv_normalizado`, sugere-se a implementação dos seguintes alertas:

1.  **Chaves Primárias Nulas**

      * **O que verificar:** Se existem registros onde `ano`, `cod_un_negocio` ou `cod_material` são nulos.
      * **Por que é importante:** A chave primária é essencial para a integridade e para os joins com outras tabelas.
      * **Alerta:** Disparar se `SELECT COUNT(*) FROM cpv_normalizado WHERE ano IS NULL OR cod_un_negocio IS NULL OR cod_material IS NULL` for maior que 0.

2.  **Duplicidade de Registros**

      * **O que verificar:** Se a combinação de `ano`, `cod_un_negocio` e `cod_material` está duplicada.
      * **Por que é importante:** A duplicação pode levar a cálculos incorretos em análises futuras.
      * **Alerta:** Disparar se `SELECT COUNT(*) FROM (SELECT ano, cod_un_negocio, cod_material, COUNT(*) FROM cpv_normalizado GROUP BY 1, 2, 3 HAVING COUNT(*) > 1)` for maior que 0.

3.  **CPV Inválido (Negativo ou Zero)**

      * **O que verificar:** Registros com `cpv <= 0`.
      * **Por que é importante:** O Custo do Produto Vendido deve ser, por definição, um valor positivo.
      * **Alerta:** Disparar se `SELECT COUNT(*) FROM cpv_normalizado WHERE cpv <= 0` for maior que 0.

4.  **Combos com CPV Incompleto**

      * **O que verificar:** A quantidade de combos com a flag `flg_combo_incompleto = 1`.
      * **Por que é importante:** Indica que o CPV de alguns combos foi calculado com base em um número insuficiente de componentes, resultando em um valor subestimado. **Este é um alerta crítico de negócio.**
      * **Alerta:** Disparar se `SELECT COUNT(*) FROM cpv_normalizado WHERE flg_combo_incompleto = 1` for maior que 0.

5.  **Variação Anual Anormal do CPV**

      * **O que verificar:** Variações de CPV muito altas para o mesmo produto entre um ano e outro.
      * **Por que é importante:** Um aumento ou queda abrupta (ex: \> 100%) pode indicar um erro de digitação na fonte ou uma falha no carregamento dos dados.
      * **Alerta:** Criar uma query que compare o `cpv` do ano `N` com o `cpv` do ano `N-1` para o mesmo `cod_material` e alertar se a variação percentual exceder um limite definido.

6.  **Produtos Ativos sem CPV**

      * **O que verificar:** Se existem produtos marcados como ativos na tabela `tb_produto_skus` que não possuem um registro de CPV para o ano corrente em `cpv_normalizado`.
      * **Por que é importante:** Pode sinalizar uma falha na extração de dados de alguma das fontes.
      * **Alerta:** Disparar se `SELECT COUNT(*) FROM tb_produto_skus s LEFT JOIN cpv_normalizado c ON s.cod_material = c.cod_material AND c.ano = [AnoCorrente] WHERE s.flg_ativo = TRUE AND c.cod_material IS NULL` for maior que 0.