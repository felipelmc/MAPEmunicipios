# Municípios: encontrar pelo nome --------------------------------------------
#
# Quase toda pergunta sobre o MAPEmunicipios começa com um nome de município e
# precisa de um código de sete dígitos. Estas funções fazem a ponte, e tratam o
# caso que sempre aparece: existem 24 municípios chamados "Bom Jesus" e 20
# chamados "Santa Luzia".

#' Procura um município pelo nome
#'
#' @param nome Nome ou parte do nome. Acento é opcional.
#' @param uf Sigla da UF, para desambiguar.
#' @param exato Se `TRUE`, exige o nome inteiro em vez de busca parcial.
#' @return Um `tibble` com os municípios encontrados.
#' @export
#' @examples
#' mape_buscar_municipio("Rio de Janeiro")
#' mape_buscar_municipio("bom jesus", uf = "PI")
#' mape_buscar_municipio("Floripa")   # devolve vazio: o nome oficial é outro
mape_buscar_municipio <- function(nome, uf = NULL, exato = FALSE) {
  x <- MAPEmunicipios::municipios
  alvo <- .mape_normalizar(nome)
  alvo <- gsub("_", " ", alvo)

  casa <- if (exato) x$busca == alvo else grepl(alvo, x$busca, fixed = TRUE)
  x <- x[casa, , drop = FALSE]
  if (!is.null(uf)) x <- x[x$sigla_uf %in% toupper(uf), , drop = FALSE]

  cols <- intersect(c("id_municipio", "nome_municipio", "sigla_uf", "nome_uf",
                      "nome_regiao"), names(x))
  tibble::as_tibble(x[, cols, drop = FALSE])
}

#' Converte nomes ou códigos em `id_municipio`
#'
#' Aceita código de sete dígitos, código de seis, ou nome. Um nome ambíguo
#' interrompe com a lista de candidatos: escolher um por conta própria seria
#' devolver o município errado em silêncio, que é o pior desfecho possível.
#'
#' @param x Vetor de nomes ou códigos.
#' @param uf Sigla da UF, para desambiguar todos de uma vez.
#' @return Vetor de `id_municipio` de sete dígitos.
#' @export
#' @examples
#' mape_resolver_municipio(c("3304557", "São Paulo"))
mape_resolver_municipio <- function(x, uf = NULL) {
  dir_mun <- MAPEmunicipios::municipios
  x <- as.character(x)

  vapply(x, function(v) {
    v <- trimws(v)
    if (grepl("^[0-9]{7}$", v)) return(v)
    if (grepl("^[0-9]{6}$", v)) {
      j <- match(v, dir_mun$id_municipio_6)
      if (!is.na(j)) return(dir_mun$id_municipio[j])
      cli::cli_abort("C\u00f3digo de seis d\u00edgitos desconhecido: {.val {v}}.")
    }

    achados <- mape_buscar_municipio(v, uf = uf, exato = TRUE)
    if (nrow(achados) == 1) return(achados$id_municipio)

    if (nrow(achados) > 1) {
      opcoes <- paste0(achados$nome_municipio, "/", achados$sigla_uf,
                       " (", achados$id_municipio, ")")
      cli::cli_abort(c(
        "{.val {v}} \u00e9 o nome de {nrow(achados)} munic\u00edpios.",
        "i" = "Passe {.arg uf} para escolher, ou use o c\u00f3digo direto.",
        "*" = "{utils::head(opcoes, 8)}"))
    }

    parciais <- mape_buscar_municipio(v, uf = uf)
    cli::cli_abort(c(
      "N\u00e3o encontrei o munic\u00edpio {.val {v}}.",
      if (nrow(parciais))
        c("i" = "Talvez seja: {.val {utils::head(parciais$nome_municipio, 5)}}")
      else
        c(">" = "Procure com {.code mape_buscar_municipio(\"parte do nome\")}.")))
  }, character(1), USE.NAMES = FALSE)
}

#' O diretório de municípios
#'
#' A espinha dorsal do painel: as equivalências entre os códigos municipais e a
#' hierarquia territorial. Vem embutido no pacote, sem download.
#'
#' @param uf Filtra por sigla de UF.
#' @param regiao Filtra por região.
#' @return Um `tibble` com 5.570 linhas, ou o recorte pedido.
#' @export
#' @examples
#' mape_municipios(uf = "AC")
#' nrow(mape_municipios())
mape_municipios <- function(uf = NULL, regiao = NULL) {
  x <- MAPEmunicipios::municipios
  if (!is.null(uf)) x <- x[x$sigla_uf %in% toupper(uf), , drop = FALSE]
  if (!is.null(regiao)) {
    alvo <- .mape_normalizar(regiao)
    x <- x[.mape_normalizar(x$nome_regiao) %in% alvo, , drop = FALSE]
  }
  tibble::as_tibble(x[, setdiff(names(x), "busca"), drop = FALSE])
}
