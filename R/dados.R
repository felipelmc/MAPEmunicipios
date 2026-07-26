# Documentação dos dados embutidos -------------------------------------------

#' Diretório dos municípios brasileiros
#'
#' A espinha dorsal do painel: as equivalências entre os códigos municipais e a
#' hierarquia territorial completa. Vem embutido no pacote, então funciona sem
#' rede.
#'
#' O bloco territorial existe **só aqui**. Nenhuma tabela de dado carrega nome
#' de município ou UF, por decisão de propriedade única: quando o mesmo campo é
#' produzido em vários lugares, as versões divergem. Na base antiga, `sigla_uf`
#' vinha do IEPS e estava preenchida em apenas 33.420 de 180.285 linhas.
#'
#' @format Um `data.frame` com 5.570 linhas e 12 colunas:
#' \describe{
#'   \item{id_municipio}{código do IBGE, 7 dígitos, como texto}
#'   \item{id_municipio_6}{código do IBGE sem o dígito verificador}
#'   \item{id_municipio_tse}{código do município no TSE}
#'   \item{nome_municipio}{nome oficial}
#'   \item{sigla_uf, nome_uf, nome_regiao}{unidade federativa e região}
#'   \item{nome_mesorregiao, nome_microrregiao}{recortes intermediários do IBGE}
#'   \item{nome_regiao_imediata, nome_regiao_intermediaria}{recortes de 2017}
#'   \item{busca}{o nome em minúsculas e sem acento, para busca}
#' }
#' @source IBGE, via `basedosdados.br_bd_diretorios_brasil.municipio`.
"municipios"

#' Catálogo das tabelas publicadas
#'
#' Uma linha por tabela, com procedência, licença, granularidade e as contagens
#' medidas no arquivo publicado.
#'
#' A coluna `camada` guarda a distinção central do projeto. `dimensao` é o painel
#' município × ano; `fonte` é o dado como foi observado, na granularidade nativa.
#' O AdaptaBrasil é um retrato de 2015, então a fonte dele tem 5.570 linhas — uma
#' por município — enquanto a dimensão que o contém tem 183.810.
#'
#' @format Um `data.frame` com 26 linhas e 19 colunas.
#' @source Repositório do ETL, `dicionario/tabelas.csv`.
"catalogo"

#' Dicionário de variáveis
#'
#' Uma linha por variável publicada, com descrição, unidade, escala, tipo,
#' domínio válido e a faixa efetivamente observada no dado.
#'
#' A coluna `problema` guarda as ressalvas conhecidas. Vale ler antes de usar uma
#' variável: é lá que está registrado, por exemplo, que a cobertura vacinal do
#' SI-PNI chega a 51.175% porque a fonte não trunca em 100%.
#'
#' O sufixo de cada nome sai de um vocabulário fechado e diz a escala: `_i`
#' contagem, `_pct` percentual de 0 a 100, `_prop` proporção de 0 a 1, `_razao`
#' quociente que pode passar de 1, `_p100k` e `_p1k` taxas, `_brl_nominal` e
#' `_brl2023` dinheiro, `_km2` área, `_idx` índice, `_cat` categoria.
#'
#' @format Um `data.frame` com 431 linhas e 14 colunas.
#' @source Repositório do ETL, `dicionario/variaveis.csv`.
"variaveis"

#' Eixos temáticos
#'
#' O vocabulário controlado que governa, ao mesmo tempo, o nome da pasta, o nome
#' do script, o nome da tabela publicada e o campo `dimensao` da documentação.
#'
#' @format Um `data.frame` com 17 linhas.
#' @source Repositório do ETL, `dicionario/dimensoes.csv`.
"dimensoes"

#' Amostra: as 27 capitais
#'
#' Um recorte pequeno com população, PIB, homicídios e indicadores de saúde das
#' 27 capitais. Existe para que os exemplos da documentação rodem sem rede.
#'
#' @format Um `data.frame` com 891 linhas e 17 colunas.
#' @source MAPEmunicipios, dimensões 02, 04, 10 e 13.
#' @examples
#' head(amostra_capitais)
"amostra_capitais"
