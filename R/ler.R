# Leitura das tabelas --------------------------------------------------------

.mape_cache <- new.env(parent = emptyenv())

#' Onde o pacote guarda as tabelas baixadas
#'
#' Por padrão usa o diretório de cache do usuário, que persiste entre sessões
#' mas some quando o sistema limpa temporários. Para fixar num lugar seu, defina
#' a variável de ambiente `MAPE_CACHE`.
#'
#' @return O caminho da pasta de cache.
#' @export
#' @examples
#' mape_cache_dir()
mape_cache_dir <- function() {
  d <- Sys.getenv("MAPE_CACHE", "")
  if (!nzchar(d)) {
    d <- tools::R_user_dir("MAPEmunicipios", "cache")
  }
  if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}

#' Apaga as tabelas baixadas
#'
#' @param tabela Slug a apagar. `NULL` apaga tudo.
#' @return Invisivelmente, o número de arquivos apagados.
#' @export
mape_limpar_cache <- function(tabela = NULL) {
  d <- mape_cache_dir()
  alvo <- if (is.null(tabela)) {
    list.files(d, pattern = "[.]parquet$", full.names = TRUE)
  } else {
    file.path(d, paste0(gsub("/", "__", mape_resolver(tabela)), ".parquet"))
  }
  alvo <- alvo[file.exists(alvo)]
  unlink(alvo)
  rm(list = ls(.mape_cache), envir = .mape_cache)
  cli::cli_alert_success("{length(alvo)} arquivo{?s} apagado{?s} do cache.")
  invisible(length(alvo))
}

.mape_url_release <- function(versao = "latest", arquivo) {
  base <- "https://github.com/mape-iesp/MAPEmunicipios-ETL/releases"
  if (identical(versao, "latest")) {
    paste0(base, "/latest/download/", arquivo)
  } else {
    paste0(base, "/download/", versao, "/", arquivo)
  }
}

#' Lê uma tabela do MAPEmunicipios
#'
#' Baixa a tabela na primeira vez, guarda em cache e devolve um `tibble`. As
#' chamadas seguintes não tocam a rede.
#'
#' O nome pode ser escrito como você lembrar: `"saude"`, `"saúde"`, `"10_saude"`
#' e `"Saude"` levam à mesma tabela. Um nome ambíguo devolve a lista de
#' candidatos em vez de escolher um por você.
#'
#' @param tabela Nome ou slug. Use [mape_tabelas()] para ver as opções.
#' @param territorio Se `TRUE`, acrescenta nome do município, UF e região. É o
#'   que quase todo mundo quer, e nenhuma tabela carrega — o bloco territorial
#'   pertence ao diretório de municípios, e só ele o publica.
#' @param anos Vetor de anos para filtrar. `NULL` traz tudo.
#' @param municipios Vetor de `id_municipio` ou de nomes. `NULL` traz todos.
#' @param uf Sigla ou vetor de siglas de UF para filtrar.
#' @param versao Tag do release. `"latest"` usa o mais recente.
#' @param quieto Se `TRUE`, não imprime mensagens.
#' @return Um `tibble`.
#' @export
#' @examples
#' \donttest{
#' saude <- mape_ler("saude")
#' rj <- mape_ler("economia", uf = "RJ", anos = 2015:2021, territorio = TRUE)
#' }
mape_ler <- function(tabela, territorio = FALSE, anos = NULL,
                     municipios = NULL, uf = NULL, versao = "latest",
                     quieto = FALSE) {
  slug <- mape_resolver(tabela)
  plano <- gsub("/", "__", slug)
  chave <- paste0(plano, "@", versao)

  if (!is.null(.mape_cache[[chave]])) {
    x <- .mape_cache[[chave]]
  } else {
    destino <- file.path(mape_cache_dir(), paste0(plano, ".parquet"))

    # Atalho para quem tem o repositório do ETL na máquina: com MAPE_ETL_RAIZ
    # definido, o pacote lê direto do disco. Serve para desenvolver o pacote
    # contra dado que ainda não foi publicado, e para gerar o site a partir da
    # mesma árvore que produziu os números.
    etl <- Sys.getenv("MAPE_ETL_RAIZ", "")
    if (!file.exists(destino) && nzchar(etl)) {
      camada <- if (grepl("/", slug)) "fonte" else "dimensao"
      local <- file.path(path.expand(etl), "dados", camada,
                         paste0(slug, ".parquet"))
      if (file.exists(local)) {
        if (!quieto) cli::cli_alert_info("Lendo {.val {slug}} do ETL local.")
        file.copy(local, destino, overwrite = TRUE)
      }
    }

    if (!file.exists(destino)) {
      url <- .mape_url_release(versao, paste0(plano, ".parquet"))
      if (!quieto) cli::cli_alert_info("Baixando {.val {slug}}...")
      ok <- tryCatch({
        utils::download.file(url, destino, mode = "wb", quiet = quieto)
        TRUE
      }, error = function(e) FALSE, warning = function(w) FALSE)

      if (!ok || !file.exists(destino) || file.size(destino) < 1000) {
        unlink(destino)
        cli::cli_abort(c(
          "N\u00e3o consegui baixar a tabela {.val {slug}}.",
          "i" = "URL: {.url {url}}",
          "i" = "Verifique sua conex\u00e3o, ou se o release {.val {versao}} existe.",
          ">" = "Releases: {.url https://github.com/mape-iesp/MAPEmunicipios-ETL/releases}"
        ))
      }
    }
    x <- tibble::as_tibble(arrow::read_parquet(destino))
    .mape_cache[[chave]] <- x
  }

  # --- Filtros --------------------------------------------------------------
  if (!is.null(anos) && "ano" %in% names(x)) {
    x <- x[x$ano %in% as.integer(anos), , drop = FALSE]
  }
  if (!is.null(municipios)) {
    ids <- mape_resolver_municipio(municipios)
    x <- x[x$id_municipio %in% ids, , drop = FALSE]
  }
  if (!is.null(uf)) {
    dir_mun <- MAPEmunicipios::municipios
    ids <- dir_mun$id_municipio[dir_mun$sigla_uf %in% toupper(uf)]
    if (!length(ids)) {
      cli::cli_abort("UF desconhecida: {.val {uf}}.")
    }
    x <- x[x$id_municipio %in% ids, , drop = FALSE]
  }

  if (territorio) x <- mape_com_territorio(x)
  x
}

#' Acrescenta o bloco territorial a uma tabela
#'
#' @param x Tabela com a coluna `id_municipio`.
#' @param colunas Colunas do diretório a trazer.
#' @return A tabela com as colunas territoriais à frente.
#' @export
mape_com_territorio <- function(x, colunas = c("nome_municipio", "sigla_uf",
                                               "nome_uf", "nome_regiao")) {
  if (!"id_municipio" %in% names(x)) {
    cli::cli_abort("A tabela n\u00e3o tem a coluna {.field id_municipio}.")
  }
  dir_mun <- MAPEmunicipios::municipios
  cols <- intersect(c("id_municipio", colunas), names(dir_mun))
  # O diretório tem uma linha por município, então a junção nunca multiplica.
  y <- merge(x, dir_mun[, cols, drop = FALSE], by = "id_municipio",
             all.x = TRUE, sort = FALSE)
  frente <- intersect(c("id_municipio", colunas, "ano"), names(y))
  tibble::as_tibble(y[, c(frente, setdiff(names(y), frente)), drop = FALSE])
}

#' Resolve um nome livre para o slug de uma tabela
#'
#' @param tabela Nome ou slug.
#' @return O slug exato.
#' @export
#' @examples
#' mape_resolver("saúde")
#' mape_resolver("meio ambiente")
mape_resolver <- function(tabela) {
  if (!is.character(tabela) || length(tabela) != 1) {
    cli::cli_abort("Passe um nome de tabela, como {.val saude}.")
  }
  disponiveis <- MAPEmunicipios::catalogo$slug
  if (tabela %in% disponiveis) return(tabela)

  alvo <- .mape_normalizar(tabela)
  sem_num <- function(s) gsub("(^|/)[0-9]{2}_", "\\1", s)

  cand <- disponiveis[
    .mape_normalizar(disponiveis) == alvo |
      sem_num(.mape_normalizar(disponiveis)) == alvo |
      sem_num(.mape_normalizar(disponiveis)) == sem_num(alvo)
  ]
  if (length(cand) == 1) return(cand)

  if (!length(cand)) {
    parciais <- disponiveis[grepl(alvo, sem_num(.mape_normalizar(disponiveis)),
                                  fixed = TRUE)]
    if (length(parciais) == 1) return(parciais)
    cand <- parciais
  }

  if (length(cand)) {
    cli::cli_abort(c(
      "O nome {.val {tabela}} corresponde a mais de uma tabela.",
      "i" = "Candidatas: {.val {cand}}"))
  }
  cli::cli_abort(c(
    "N\u00e3o encontrei a tabela {.val {tabela}}.",
    ">" = "Use {.run MAPEmunicipios::mape_tabelas()} para ver as {length(disponiveis)} dispon\u00edveis."))
}

# Transliteração determinística. Não usa iconv(to = "ASCII//TRANSLIT") porque o
# resultado dele depende da libiconv do sistema: no macOS "ç" não vira "c".
.mape_normalizar <- function(s) {
  de   <- "\u00e1\u00e0\u00e2\u00e3\u00e4\u00e9\u00e8\u00ea\u00eb\u00ed\u00ec\u00ee\u00ef\u00f3\u00f2\u00f4\u00f5\u00f6\u00fa\u00f9\u00fb\u00fc\u00e7\u00c1\u00c0\u00c2\u00c3\u00c4\u00c9\u00c8\u00ca\u00cb\u00cd\u00cc\u00ce\u00cf\u00d3\u00d2\u00d4\u00d5\u00d6\u00da\u00d9\u00db\u00dc\u00c7"
  para <- "aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC"
  s <- tolower(chartr(de, para, s))
  s <- gsub("[^a-z0-9/]+", "_", s)
  gsub("^_+|_+$", "", s)
}
