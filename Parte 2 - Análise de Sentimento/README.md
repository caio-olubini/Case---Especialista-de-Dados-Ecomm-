# Análise de Sentimentos em Reviews de Produtos com Transformers

![Análise de Sentimentos](https://img.shields.io/badge/NLP-An%C3%A1lise%20de%20Sentimentos-blue)
![Hugging Face](https://img.shields.io/badge/%F0%9F%A4%97%20Hugging%20Face-Transformers-yellow)
![Status](https://img.shields.io/badge/status-em%20desenvolvimento-orange)

## ✒️ Autor

- **Caio Olubini**
- **Contato:** caio.olubini@gmail.com

---

## 🎯 Sobre o Projeto

Este projeto implementa um modelo de **detecção de sentimento** em reviews de produtos, utilizando a arquitetura Transformer através da biblioteca Hugging Face. O objetivo é classificar automaticamente as opiniões dos consumidores como positivas, negativas ou neutras, gerando insights valiosos de forma eficiente.

O modelo demonstrou alta performance, classificando todas as amostras do conjunto de dados em **720 segundos**, sem a necessidade de aceleração por GPU. A escolha pela biblioteca `transformers` se deu por ser uma abstração de alto nível e representar o estado da arte em processamento de linguagem natural (NLP), garantindo precisão e escalabilidade.

### O que são Hugging Face e Transformers?

**Hugging Face 🤗** é uma plataforma que democratiza o acesso a modelos de Machine Learning, principalmente para NLP. **Transformers** são uma arquitetura de rede neural que revolucionou a forma como lidamos com textos, permitindo um entendimento profundo de contexto e significado, superando modelos sequenciais tradicionais.

---

## 📂 Estrutura do Notebook

O projeto está organizado de forma clara e sequencial dentro de um único notebook, facilitando a compreensão e a reprodutibilidade. As seções são:

1.  **Carregando Pacotes:** Importação das bibliotecas essenciais para a análise.
2.  **Lendo Datasets:** Carregamento dos dados de reviews que servirão de base para o modelo.
3.  **Análise Exploratória:** Uma investigação inicial para entender a distribuição, características e padrões dos dados.
4.  **Pré-processamento e Engenharia de Recursos:** Etapa de limpeza e preparação dos textos para a modelagem.
5.  **Modelagem:** Construção e treinamento do modelo de análise de sentimentos.
6.  **Análise de Sentimento:** Aplicação do modelo treinado para classificar as reviews.
7.  **Insights & Análise de Sentimentos:** Extração de conclusões e visualização dos resultados obtidos.

---

## 🚀 Próximos Passos (Evoluções)

Para garantir a contínua relevância e precisão do modelo, as seguintes evoluções estão planejadas:

-   **Implementação de Avaliação de Classificação:**
    -   Desenvolvimento de um processo de verificação manual da acurácia do modelo. A ideia é extrair amostras estratificadas periodicamente para que a performance seja auditada e o modelo, mantido e recalibrado conforme necessário.

-   **Implementação de Pipeline Produtivo:**
    -   Criação de um pipeline de dados automatizado no **Google Cloud Platform (GCP)**. O objetivo é automatizar a ingestão de novas amostras de reviews, aplicar a classificação de sentimento e salvar os resultados de forma produtiva e escalável na nuvem.