# Catálogo: o que existe e onde ----------------------------------------------
#
# Estas funções respondem à pergunta que vem antes de qualquer download: o que
# tem aqui dentro? Todas trabalham sobre dados embutidos no pacote, então
# funcionam sem rede e sem baixar nada.

#' Lista as tabelas disponíveis
#'
#' @param eixo Filtra por eixo temático (`"saude"`, `"03_meio_ambiente"`...).
#' @param camada `"dimensao"` para o painel município × ano, `"fonte"` para o
#'   dado como foi observado, `NULL` para as duas.
#' @param busca Texto a procurar no nome e na descrição.
#' @return Um `tibble` com uma tabela por linha.
#' @export
#' @examples
#' mape_tabelas()
#' mape_tabelas(camada = "fonte")
#' mape_tabelas(busca = "vacina")
mape_tabelas <- function(eixo = NULL, camada = NULL, busca = NULL) {
  x <- MAPEmunicipios::catalogo

  if (!is.null(eixo)) {
    alvo <- .mape_normalizar(eixo)
    sem_num <- function(s) gsub("^[0-9]{2}_", "", s)
    x <- x[sem_num(.mape_normalizar(x$dimensao)) == sem_num(alvo) |
             .mape_normalizar(x$dimensao) == alvo, , drop = FALSE]
    if (!nrow(x)) {
      cli::cli_abort(c("Eixo {.val {eixo}} n\u00e3o encontrado.",
                       ">" = "Veja {.run MAPEmunicipios::mape_eixos()}."))
    }
  }
  if (!is.null(camada)) x <- x[x$camada %in% camada, , drop = FALSE]
  if (!is.null(busca)) {
    alvo <- .mape_normalizar(busca)
    onde <- .mape_normalizar(paste(x$slug, x$nome_publicado, x$descricao))
    x <- x[grepl(alvo, onde, fixed = TRUE), , drop = FALSE]
  }

  tibble::as_tibble(x[, c("slug", "camada", "nome_publicado", "linhas",
                          "colunas", "municipios", "ano_min", "ano_max")])
}

#' Lista os eixos temáticos
#'
#' @return Um `tibble` com um eixo por linha e a contagem de tabelas e
#'   variáveis de cada um.
#' @export
#' @examples
#' mape_eixos()
mape_eixos <- function() {
  cat_tab <- MAPEmunicipios::catalogo
  vars <- MAPEmunicipios::variaveis

  eixos <- sort(unique(cat_tab$dimensao[!is.na(cat_tab$dimensao)]))
  res <- do.call(rbind, lapply(eixos, function(e) {
    tabs <- cat_tab[!is.na(cat_tab$dimensao) & cat_tab$dimensao == e, ]
    data.frame(
      eixo = e,
      rotulo = tabs$nome_publicado[tabs$camada == "dimensao"][1],
      tabelas = nrow(tabs),
      variaveis = sum(!is.na(vars$dimensao) & vars$dimensao == e),
      linhas = max(tabs$linhas),
      anos = if (all(is.na(tabs$ano_min))) NA_character_ else
        paste0(min(tabs$ano_min, na.rm = TRUE), "-", max(tabs$ano_max, na.rm = TRUE)),
      stringsAsFactors = FALSE)
  }))
  res$rotulo[is.na(res$rotulo)] <- res$eixo[is.na(res$rotulo)]
  tibble::as_tibble(res)
}

#' Procura uma variável
#'
#' Busca no nome e na descrição das 431 variáveis documentadas. É a função para
#' quando você sabe o que quer medir e não sabe como a coluna se chama.
#'
#' @param busca Texto a procurar. `NULL` devolve tudo.
#' @param tabela Restringe a uma tabela.
#' @param eixo Restringe a um eixo temático.
#' @param detalhes Se `TRUE`, traz também domínio, faixa observada e ressalvas.
#' @return Um `tibble` com uma variável por linha.
#' @export
#' @examples
#' mape_variaveis("homicidio")
#' mape_variaveis("vacina", eixo = "10_saude")
#' mape_variaveis("pib", detalhes = TRUE)
mape_variaveis <- function(busca = NULL, tabela = NULL, eixo = NULL,
                           detalhes = FALSE) {
  x <- MAPEmunicipios::variaveis

  if (!is.null(tabela)) {
    slug <- mape_resolver(tabela)
    # Pedir uma dimensão traz também as variáveis das fontes dela, porque a
    # dimensão é a união das fontes.
    x <- x[x$tabela == slug | startsWith(x$tabela, paste0(slug, "/")), , drop = FALSE]
  }
  if (!is.null(eixo)) {
    alvo <- .mape_normalizar(eixo)
    sem_num <- function(s) gsub("^[0-9]{2}_", "", s)
    x <- x[!is.na(x$dimensao) &
             (sem_num(.mape_normalizar(x$dimensao)) == sem_num(alvo) |
                .mape_normalizar(x$dimensao) == alvo), , drop = FALSE]
  }
  if (!is.null(busca)) {
    alvo <- .mape_normalizar(busca)
    # Uma busca com várias palavras exige todas, o que evita que "cobertura
    # vacinal" devolva tudo que tem "cobertura".
    termos <- strsplit(alvo, "_")[[1]]
    termos <- termos[nzchar(termos)]
    casa <- Reduce(`&`, lapply(termos, function(t) grepl(t, x$busca, fixed = TRUE)))
    x <- x[casa, , drop = FALSE]
  }

  cols <- if (detalhes) {
    c("nome_canonico", "tabela", "descricao", "unidade", "tipo",
      "dominio_valido", "minimo", "maximo", "pct_na", "problema")
  } else {
    c("nome_canonico", "tabela", "descricao", "unidade")
  }
  tibble::as_tibble(x[, intersect(cols, names(x)), drop = FALSE])
}

#' Mostra tudo o que se sabe sobre uma variável
#'
#' @param nome Nome canônico da variável.
#' @return Invisivelmente, a linha do dicionário.
#' @export
#' @examples
#' mape_sobre("pib_per_capita_brl2023")
mape_sobre <- function(nome) {
  x <- MAPEmunicipios::variaveis
  linha <- x[x$nome_canonico == nome, , drop = FALSE]

  if (!nrow(linha)) {
    parecidas <- x$nome_canonico[grepl(.mape_normalizar(nome), x$busca, fixed = TRUE)]
    cli::cli_abort(c(
      "N\u00e3o encontrei a vari\u00e1vel {.val {nome}}.",
      if (length(parecidas))
        c("i" = "Talvez seja: {.val {utils::head(parecidas, 5)}}")
      else
        c(">" = "Procure com {.code mape_variaveis(\"parte do nome\")}.")))
  }
  linha <- linha[1, ]

  cli::cli_h1(linha$nome_canonico)
  if (!is.na(linha$descricao) && nzchar(linha$descricao)) {
    cli::cli_text(linha$descricao)
    cli::cli_text("")
  }
  cli::cli_dl(c(
    "tabela" = linha$tabela,
    "unidade" = if (is.na(linha$unidade)) "n\u00e3o informada" else linha$unidade,
    "tipo" = linha$tipo,
    "faixa observada" = if (is.na(linha$minimo)) "\u2014" else
      paste0(signif(linha$minimo, 5), " a ", signif(linha$maximo, 5)),
    "vazios" = paste0(round(linha$pct_na, 1), "%")
  ))
  if (!is.na(linha$problema) && nzchar(linha$problema)) {
    cli::cli_text("")
    cli::cli_alert_warning("Ressalva")
    cli::cli_text(linha$problema)
  }
  cli::cli_text("")
  cli::cli_text("Para ler: {.code mape_ler(\"{linha$tabela}\")}")
  invisible(linha)
}
