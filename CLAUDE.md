# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Visão geral

Pacote R que dá acesso aos dados do **MAPEmunicipios**: um painel dos 5.570 municípios brasileiros, de 1989 a 2024, em 17 eixos temáticos, 26 tabelas e 431 variáveis documentadas.

Este é o repositório **público**, para quem consome. Quem **produz** os dados trabalha no outro:

| | este repositório | `MAPEmunicipios-ETL` |
|---|---|---|
| Papel | consumir | extrair, tratar, validar, publicar |
| Público | pesquisadores, jornalistas, sociedade civil | pesquisadores do MAPE |
| Precisa de credencial GCP | **nunca** | sim, para reextrair |
| Muda quando | a interface de consumo muda | uma fonte publica dado novo |

O raciocínio da separação está em [`docs/decisao-dois-repositorios.md`](https://github.com/mape-iesp/MAPEmunicipios-ETL/blob/main/docs/decisao-dois-repositorios.md), no ETL.

**O único acoplamento entre os dois é um release do GitHub.** Nenhum código é compartilhado, nenhum caminho de arquivo atravessa a fronteira.

## Comandos

```bash
# Desenvolvimento
Rscript -e 'roxygen2::roxygenise()'                 # regera man/ e NAMESPACE
R CMD INSTALL --no-docs .                            # instala local
Rscript -e 'testthat::test_dir("tests/testthat", package = "MAPEmunicipios", load_package = "installed")'

# Checagem completa (precisa do pandoc para a vinheta)
export RSTUDIO_PANDOC=/Applications/quarto/bin/tools/aarch64
R CMD build . && R CMD check --no-manual MAPEmunicipios_0.1.0.tar.gz

# Site
quarto render site                                   # gera site/_site/
cd site/_site && python3 -m http.server 4321         # visualizar

# Regerar os dados embutidos e os do site (exige o ETL na máquina)
MAPE_ETL_RAIZ=~/Desktop/MAPEmunicipios-ETL Rscript data-raw/preparar_dados.R
MAPE_ETL_RAIZ=~/Desktop/MAPEmunicipios-ETL Rscript site/gerar_dados.R
```

---

## Quais dados estão aqui, e como chegam

Esta é a pergunta que mais confunde quem chega. Há **três** origens de dado, e só uma delas envolve rede.

### 1. Dados embutidos no pacote — `data/`, 168 KB, versionados

Cinco objetos, disponíveis assim que se faz `library(MAPEmunicipios)`. Não baixam nada.

| objeto | dimensões | o que é |
|---|---|---|
| `municipios` | 5.570 × 12 | o diretório: códigos e hierarquia territorial |
| `catalogo` | 26 × 19 | as tabelas publicadas, com procedência e contagens |
| `variaveis` | 431 × 14 | o dicionário: unidade, escala, tipo, domínio, ressalvas |
| `dimensoes` | 17 × 4 | o vocabulário dos eixos |
| `amostra_capitais` | 891 × 17 | série das 27 capitais, para exemplos sem rede |

**O critério do que entra:** só o que é preciso para o pacote *funcionar antes de qualquer download* — resolver o nome de um município, listar as tabelas, procurar uma variável. Dado de análise **não entra**.

Eles são gerados por `data-raw/preparar_dados.R`, que lê do ETL local. O script exige `MAPE_ETL_RAIZ` apontando para o repositório do ETL e falha com mensagem clara se não achar.

### 2. As tabelas de dado — baixadas sob demanda, **não versionadas**

`mape_ler("saude")` baixa `10_saude.parquet` de um release do GitHub, guarda em cache e devolve um `tibble`. As chamadas seguintes não tocam a rede.

```
https://github.com/mape-iesp/MAPEmunicipios-ETL/releases/latest/download/10_saude.parquet
```

O nome do arquivo no release achata a barra do slug em duplo sublinhado, porque release do GitHub não tem pastas: `03_meio_ambiente/adaptabrasil` vira `03_meio_ambiente__adaptabrasil.parquet`.

**Nenhum `.parquet` existe neste repositório.** As 26 tabelas somam 204 MB e ficam só no ETL. Versioná-las aqui duplicaria tudo e ficaria velho a cada release.

O cache fica em `tools::R_user_dir("MAPEmunicipios", "cache")`, ou onde `MAPE_CACHE` apontar. `mape_cache_dir()` mostra, `mape_limpar_cache()` apaga.

#### O atalho de desenvolvimento

`mape_ler()` verifica a variável de ambiente **`MAPE_ETL_RAIZ`** antes de tentar a rede. Se ela estiver definida e o arquivo existir em disco, o pacote lê direto do ETL local:

```r
Sys.setenv(MAPE_ETL_RAIZ = "~/Desktop/MAPEmunicipios-ETL")
mape_ler("saude")   # lê de dados/dimensao/10_saude.parquet, sem rede
```

Isso existe por um motivo concreto: **o release ainda não foi publicado**. Sem esse atalho, nada neste pacote funcionaria hoje. Ele também serve para desenvolver contra dado que ainda não saiu, e foi como o site foi gerado.

### 3. Dados do site — `site/dados/`, 304 KB, versionados

Oito arquivos JSON que alimentam as visualizações interativas. O site é **estático**: nada de servidor, nada de Shiny. Os gráficos rodam no navegador com Observable Plot lendo esses arquivos.

| arquivo | o que é |
|---|---|
| `capitais.json` | série das 27 capitais, 5 indicadores |
| `variaveis.json` | as 431 variáveis, para a busca interativa |
| `catalogo.json` | as 26 tabelas, para a tabela filtrável |
| `cobertura.json` | quantos municípios cada dimensão cobre, ano a ano |
| `por_uf.json` | mediana municipal por UF, 4 anos |
| `eixos.json`, `ranking_homicidios_2019.json`, `resumo.json` | agregados menores |

São gerados por `site/gerar_dados.R`, que também exige `MAPE_ETL_RAIZ`. **São versionados de propósito**: o workflow do GitHub Actions que publica o site não tem acesso ao ETL, então regerá-los lá seria impossível.

### Resumo

**472 KB de dado neste repositório**, todo derivado e todo regenerável a partir do ETL. Zero tabela de análise. As 26 tabelas vêm do release, sob demanda, com cache.

---

## Arquitetura do pacote

### As duas camadas de tabela

Este é o único conceito que precisa ser entendido antes de mexer em qualquer coisa.

A **dimensão** é o painel município × ano. `03_meio_ambiente` tem 183.810 linhas.

A **fonte** guarda o dado como foi observado, na granularidade nativa. `03_meio_ambiente/adaptabrasil` tem 5.570 linhas, porque o AdaptaBrasil publica um retrato de 2015 — e a dimensão o repete em onze anos para preencher o painel.

Na API, a fonte se distingue pela barra: `mape_ler("meio_ambiente")` traz a dimensão, `mape_ler("meio_ambiente/adaptabrasil")` traz a fonte.

### Os arquivos de `R/`

| arquivo | o que tem |
|---|---|
| `ler.R` | `mape_ler()`, cache, download, `mape_resolver()`, `mape_com_territorio()` |
| `catalogo.R` | `mape_tabelas()`, `mape_eixos()`, `mape_variaveis()`, `mape_sobre()` |
| `municipios.R` | `mape_buscar_municipio()`, `mape_resolver_municipio()`, `mape_municipios()` |
| `juntar.R` | `mape_juntar()`, com as recusas |
| `indicadores.R` | `.indicadores` (o catálogo), `mape_calcular()`, `mape_ranking()` |
| `dados.R` | documentação roxygen dos cinco objetos embutidos |

### O contrato de chave

`id_municipio` é **texto de sete dígitos**, sempre. `ano` é inteiro.

Lido como número, o código perde o zero à esquerda de todo município do Acre, de Alagoas e do Amazonas — e as junções silenciosamente deixam de casar. Código também não é quantidade: nada deveria somar ou tirar média de um identificador municipal.

### O vocabulário de sufixos

Todo nome de coluna termina num sufixo do vocabulário fechado, e ele diz a escala:

`_i` contagem · `_pct` 0 a 100 · `_prop` 0 a 1 · `_razao` quociente que pode passar de 1 · `_p100k` `_p1k` `_p100dom` taxas · `_brl_nominal` `_brl2023` dinheiro · `_km` `_km2` · `_idx` índice · `_cat` categoria · prefixos `flag_` e `ano_ref_`

O teste `test-catalogo.R` verifica que **toda** variável do dicionário obedece. Se você acrescentar um sufixo novo, precisa acrescentá-lo lá também — o teste falha de propósito.

---

## Princípios que o código segue

Estes não são estilo: cada um corresponde a um defeito real do pipeline antigo.

**Recusar em vez de avisar.** `mape_juntar()` para quando uma tabela tem chave duplicada ou não tem coluna `ano`. O pipeline antigo juntava, a chave duplicada multiplicava as linhas, e um `distinct()` cego no fim apagava a evidência. Duas tabelas do MAPEmunicipios ainda têm chave duplicada herdada da fonte, e a função nomeia qual.

**Interromper em ambiguidade.** `mape_resolver_municipio("Bom Jesus")` não escolhe: lista os cinco candidatos e para. Escolher um por conta própria devolveria o município errado em silêncio, que é o pior desfecho possível.

**Nomear a coluna ausente.** `mape_calcular()` não devolve `NA` quando falta um insumo — diz qual coluna falta. Um indicador que devolve `NA` porque a coluna mudou de nome parece dado ausente e é código quebrado.

**Divisão por zero vira `NA`, nunca `Inf`.** Um `Inf` atravessa qualquer média sem reclamar e contamina o resultado.

**Carregar a ressalva junto do dado.** `mape_sobre()` mostra o defeito conhecido antes de a pessoa publicar o número. A cobertura vacinal do SI-PNI chega a 51.175% porque a fonte não trunca em 100%.

---

## Armadilhas conhecidas

**Transliteração de acento.** Use `chartr()` com o mapa explícito de `.mape_normalizar()`, nunca `iconv(to = "ASCII//TRANSLIT")`. O resultado do `iconv` depende da libiconv do sistema: no macOS "ç" não vira "c", e "Educação" deixa de casar com "educacao".

**Não-ASCII em código quebra o `R CMD check`.** Comentários com acento passam; **strings não**. Toda string com acento precisa de escape `\uXXXX`. Há um conversor em `/tmp/ascii.py` do histórico, mas o essencial é: escreva a string com escape desde o começo, ou rode `tools::showNonASCIIfile()` antes de commitar.

**Constante global em script sobrescreve a anterior.** Não declare `FONTE <- "..."` no topo de um arquivo. Foi assim que, no ETL, o `cadunico` passou a procurar o bruto na pasta do `disque100`.

**`Inputs.select` do Observable formata número.** Passar `2019` mostra "2.019". Passe `"2019"` como texto e converta depois.

**Tabela do Observable estoura a largura do corpo.** Use `//| column: page` e envolva em `<div class="tabela-rolagem">`, senão as últimas colunas ficam cortadas em vez de roláveis.

---

## Quando o ETL muda

O acoplamento é frouxo de propósito, mas não é zero.

**Variável nova numa tabela existente:** nada a fazer. `mape_variaveis()` lê `data/variaveis.rda`, então basta regerar os dados embutidos quando quiser que ela apareça na busca.

**Tabela nova:** regerar `data/catalogo.rda`. Sem isso, `mape_resolver()` não a encontra.

**Coluna renomeada:** se algum indicador de `.indicadores` dependia dela, ele quebra — e a mensagem de `mape_calcular()` nomeia a coluna. O de-para está em `dicionario/deprecacao.csv`, no ETL.

**Release novo:** nada a fazer. `versao = "latest"` é o padrão.

---

## O estado atual

- **16 funções exportadas**, 63 testes, `R CMD check` Status OK sem notes
- **Site** de 5 páginas em `site/`, publicado por GitHub Actions em `site.yaml`
- **Branch `v0-tabelas-modulares`**, ainda não mesclada

### O que está aberto

**O release do ETL não foi publicado.** Sem ele, `mape_ler()` falha com uma mensagem que explica o porquê. Use `MAPE_ETL_RAIZ` para desenvolver enquanto isso.

**O GitHub Pages precisa ser habilitado** nas configurações do repositório, com origem "GitHub Actions", para o site sair do ar local.

**Duas tabelas têm chave duplicada** herdada da fonte — `06_financas` e `15_dados_historicos`. Não é defeito deste pacote, e corrigir exige reprocessar a fonte no ETL.

---

## Licença

Código sob MIT. Dados sob CC BY 4.0, condicionada pelas licenças das fontes. Três precisam de verificação antes de qualquer uso comercial: IEPS Data, Anuário do FBSP e o pacote de replicação de Kustov & Pardelli.
