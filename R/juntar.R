# Junção de tabelas ----------------------------------------------------------

#' Junta tabelas do MAPEmunicipios
#'
#' Junta pelo par `id_municipio` + `ano`, conferindo antes se a junção faz
#' sentido. Ela **recusa** três combinações que produziriam resultado enganoso,
#' em vez de produzi-lo em silêncio:
#'
#' - Tabela com chave duplicada multiplicaria linhas. Duas tabelas do
#'   MAPEmunicipios têm esse defeito herdado da fonte, e a função nomeia qual.
#' - Tabela sem coluna `ano` juntada a um painel replicaria o valor em todos os
#'   anos. Exige `replicar = TRUE` para fazer isso.
#' - Tabela de cobertura baixa gera coluna quase toda vazia. A função avisa com
#'   o número antes de juntar.
#'
#' @param ... Nomes de tabelas, ou data frames.
#' @param tipo `"full"` mantém tudo, `"left"` mantém as linhas da primeira,
#'   `"inner"` só o que existe nas duas.
#' @param territorio Se `TRUE`, acrescenta o bloco territorial no fim.
#' @param replicar Autoriza juntar tabela sem `ano` por município.
#' @param quieto Se `TRUE`, não imprime o relatório.
#' @return Um `tibble`, com o atributo `mape_relatorio`.
#' @export
#' @examples
#' \donttest{
#' d <- mape_juntar("seguranca", "populacao", territorio = TRUE)
#' attr(d, "mape_relatorio")
#' }
mape_juntar <- function(..., tipo = c("full", "left", "inner"),
                        territorio = FALSE, replicar = FALSE, quieto = FALSE) {
  tipo <- match.arg(tipo)
  entradas <- list(...)
  if (length(entradas) == 1 && is.list(entradas[[1]]) &&
      !is.data.frame(entradas[[1]])) {
    entradas <- entradas[[1]]
  }
  if (length(entradas) == 1 && is.character(entradas[[1]]) &&
      length(entradas[[1]]) > 1) {
    entradas <- as.list(entradas[[1]])
  }
  if (!length(entradas)) cli::cli_abort("Nada para juntar.")

  partes <- lapply(entradas, function(e) {
    if (is.data.frame(e)) e else mape_ler(e, quieto = quieto)
  })
  # Os nomes precisam ser únicos, e não só informativos. Com dois data frames
  # anônimos os dois viravam "tabela", e `partes[["tabela"]]` devolvia sempre o
  # primeiro — o diagnóstico conferia a mesma tabela duas vezes e nunca a
  # segunda. Por isso o laço abaixo percorre por índice.
  nomes <- vapply(seq_along(entradas), function(i) {
    e <- entradas[[i]]
    if (is.data.frame(e)) {
      nm <- names(entradas)[i]
      if (!is.null(nm) && nzchar(nm)) nm else paste0("tabela_", i)
    } else {
      mape_resolver(e)
    }
  }, character(1))
  names(partes) <- make.unique(nomes)

  # --- Diagnóstico ANTES de juntar -----------------------------------------
  n_mun <- nrow(MAPEmunicipios::municipios)
  bloqueios <- character()

  for (i in seq_along(partes)) {
    nm <- names(partes)[i]
    p <- partes[[i]]
    chaves <- intersect(c("id_municipio", "ano"), names(p))
    if (!length(chaves)) {
      bloqueios <- c(bloqueios, sprintf("%s: n\u00e3o tem id_municipio", nm))
      next
    }
    k <- do.call(paste, as.list(p[, chaves, drop = FALSE]))
    if (anyDuplicated(k)) {
      bloqueios <- c(bloqueios, sprintf(
        "%s: %d chaves duplicadas, %d linhas excedentes",
        nm, length(unique(k[duplicated(k)])), sum(duplicated(k))))
    }
    if (!"ano" %in% names(p) && !replicar) {
      bloqueios <- c(bloqueios, sprintf(
        "%s: n\u00e3o tem coluna `ano`, e junt\u00e1-la replicaria cada valor em todos os anos",
        nm))
    }
    cob <- round(100 * length(unique(p$id_municipio)) / n_mun, 1)
    if (cob < 50 && !quieto) {
      cli::cli_alert_warning(
        "{.val {nm}} cobre {cob}% dos munic\u00edpios: a jun\u00e7\u00e3o gera coluna quase vazia.")
    }
  }

  if (length(bloqueios)) {
    cli::cli_abort(c(
      "N\u00e3o d\u00e1 para juntar assim:",
      stats::setNames(bloqueios, rep("x", length(bloqueios))),
      "i" = "Juntar mesmo assim multiplicaria linhas ou replicaria valores sem registro.",
      ">" = "Para tabela sem ano, passe {.code replicar = TRUE}."))
  }

  # --- Junção ---------------------------------------------------------------
  relatorio <- data.frame(passo = 0, tabela = names(partes)[1],
                          linhas = nrow(partes[[1]]),
                          colunas = ncol(partes[[1]]), stringsAsFactors = FALSE)
  res <- partes[[1]]

  if (length(partes) > 1) {
    for (i in 2:length(partes)) {
      by <- intersect(intersect(c("id_municipio", "ano"), names(res)),
                      names(partes[[i]]))
      res <- switch(
        tipo,
        full  = merge(res, partes[[i]], by = by, all = TRUE, sort = FALSE),
        left  = merge(res, partes[[i]], by = by, all.x = TRUE, sort = FALSE),
        inner = merge(res, partes[[i]], by = by, sort = FALSE))
      relatorio <- rbind(relatorio, data.frame(
        passo = i - 1, tabela = names(partes)[i], linhas = nrow(res),
        colunas = ncol(res), stringsAsFactors = FALSE))
    }
  }

  # O território entra por último. A ordem importa: o diretório tem uma linha
  # por município e o painel tem uma por município-ano, então ele é sempre o
  # lado "um" da junção.
  if (territorio) {
    res <- mape_com_territorio(res)
    relatorio <- rbind(relatorio, data.frame(
      passo = nrow(relatorio), tabela = "territorio", linhas = nrow(res),
      colunas = ncol(res), stringsAsFactors = FALSE))
  }

  ordem <- intersect(c("id_municipio", "nome_municipio", "sigla_uf", "nome_uf",
                       "nome_regiao", "ano"), names(res))
  res <- res[, c(ordem, setdiff(names(res), ordem)), drop = FALSE]
  res <- res[order(res$id_municipio, if ("ano" %in% names(res)) res$ano else 0), ]

  res <- tibble::as_tibble(res)
  attr(res, "mape_relatorio") <- relatorio
  if (!quieto) {
    cli::cli_alert_success(
      "{nrow(res)} linha{?s} x {ncol(res)} coluna{?s}, de {length(partes)} tabela{?s}.")
  }
  res
}
