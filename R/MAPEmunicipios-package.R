#' @keywords internal
#' @section Por onde começar:
#'
#' O pacote responde a três perguntas, nesta ordem:
#'
#' **O que existe?** [mape_eixos()] lista os 17 eixos temáticos,
#' [mape_tabelas()] lista as 26 tabelas, [mape_variaveis()] procura entre as 431
#' variáveis pelo nome ou pela descrição.
#'
#' **Como pego?** [mape_ler()] baixa uma tabela e guarda em cache.
#' [mape_juntar()] combina tabelas conferindo antes se a junção faz sentido.
#'
#' **O que dá para calcular?** [mape_indicadores()] lista os indicadores
#' derivados, [mape_calcular()] os calcula e [mape_ranking()] monta o ranking de
#' municípios por qualquer um deles.
#'
#' @section A chave:
#'
#' Toda tabela tem `id_municipio` (texto de sete dígitos) e, quando é painel,
#' `ano` (inteiro). O código do IBGE é **texto** de propósito: lê-lo como número
#' perde o zero à esquerda de todo município do Acre, de Alagoas e do Amazonas.
#'
#' @section Dimensão e fonte:
#'
#' Cada tabela é de uma das duas camadas, e a diferença importa.
#'
#' A **dimensão** é o painel município × ano. É o que a maioria das pessoas quer:
#' uma linha por município por ano, pronta para juntar com outra dimensão.
#'
#' A **fonte** guarda o dado como foi observado, na granularidade nativa dele. O
#' AdaptaBrasil publica um retrato de 2015, então `03_meio_ambiente/adaptabrasil`
#' tem 5.570 linhas, uma por município. A dimensão que o contém tem 183.810,
#' porque repete a mesma medição em onze anos para preencher o painel.
#'
#' Ler a fonte responde "quantos municípios foram medidos?". Ler a dimensão
#' responde "como isso se comporta ao longo do tempo, ao lado de outra coisa?".
#'
#' @section Não é preciso credencial:
#'
#' Nada aqui exige conta no Google Cloud. Os dados vêm de um release público do
#' GitHub. A credencial só é necessária para quem vai *atualizar* uma fonte no
#' repositório do ETL.
"_PACKAGE"

## usethis namespace: start
#' @importFrom tibble as_tibble
#' @importFrom utils download.file head
#' @importFrom stats setNames
## usethis namespace: end
NULL
