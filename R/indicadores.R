# Indicadores derivados ------------------------------------------------------
#
# Um indicador é uma conta entre colunas que a base não guarda pronta. O catálogo
# existe por um motivo concreto: a base publicada tem uma coluna de PIB per
# capita que NÃO é reproduzível a partir dela, porque o denominador usado foi uma
# segunda extração da população, descartada logo depois de dividir.
#
# Aqui cada indicador declara de que colunas depende. Se uma faltar, a função
# nomeia a coluna ausente e para, em vez de devolver NA e deixar parecer que o
# dado não existe.

.indicadores <- list(

  pib_per_capita = list(
    rotulo = "PIB per capita",
    unidade = "R$ de dezembro de 2023",
    tabelas = c("04_economia", "02_populacao"),
    precisa = c("pib_brl2023", "populacao_residente_i"),
    calcular = function(d) d$pib_brl2023 / d$populacao_residente_i,
    interpretacao = paste(
      "Quanto o munic\u00edpio produz por habitante. Cuidado ao comparar munic\u00edpios",
      "com grande atividade extrativa ou industrial: o PIB \u00e9 produzido l\u00e1, mas",
      "a renda n\u00e3o fica necessariamente l\u00e1.")
  ),

  taxa_homicidios = list(
    rotulo = "Homic\u00eddios por 100 mil habitantes",
    unidade = "\u00f3bitos por 100 mil habitantes",
    tabelas = c("13_seguranca", "02_populacao"),
    precisa = c("sim_obitos_homicidio_i", "populacao_residente_i"),
    calcular = function(d) d$sim_obitos_homicidio_i / d$populacao_residente_i * 1e5,
    interpretacao = paste(
      "Homic\u00eddios registrados no Sistema de Informa\u00e7\u00f5es sobre Mortalidade,",
      "sobre a popula\u00e7\u00e3o do mesmo ano. Em munic\u00edpios pequenos, um \u00fanico caso",
      "move muito a taxa \u2014 compare com cautela abaixo de 20 mil habitantes.")
  ),

  receita_propria_per_capita = list(
    rotulo = "Receita pr\u00f3pria per capita",
    unidade = "R$ de dezembro de 2023",
    tabelas = c("06_financas", "02_populacao"),
    precisa = c("siconfi_receitas_proprias_brl2023", "populacao_residente_i"),
    calcular = function(d) d$siconfi_receitas_proprias_brl2023 / d$populacao_residente_i,
    interpretacao = paste(
      "Quanto o munic\u00edpio arrecada por conta pr\u00f3pria, por habitante. Separa o",
      "munic\u00edpio que se sustenta do que depende de transfer\u00eancia.")
  ),

  cobertura_esgoto = list(
    rotulo = "Cobertura de esgoto na popula\u00e7\u00e3o urbana",
    unidade = "%",
    tabelas = "03_meio_ambiente",
    precisa = c("snis_populacao_urbana_atendida_esgoto_i", "snis_populacao_urbana_i"),
    calcular = function(d) {
      100 * d$snis_populacao_urbana_atendida_esgoto_i / d$snis_populacao_urbana_i
    },
    interpretacao = paste(
      "Percentual da popula\u00e7\u00e3o urbana atendida por rede de esgoto, segundo o",
      "SNIS. A cobertura do SNIS \u00e9 declarat\u00f3ria: munic\u00edpio que n\u00e3o responde ao",
      "levantamento aparece como vazio, e n\u00e3o como zero.")
  ),

  prejuizo_desastres_per_capita = list(
    rotulo = "Preju\u00edzo com desastres por habitante",
    unidade = "R$ de dezembro de 2023",
    tabelas = c("03_meio_ambiente", "02_populacao"),
    precisa = c("s2id_prejuizos_publicos_brl2023", "s2id_prejuizos_privados_brl2023",
                "populacao_residente_i"),
    calcular = function(d) {
      (d$s2id_prejuizos_publicos_brl2023 + d$s2id_prejuizos_privados_brl2023) /
        d$populacao_residente_i
    },
    interpretacao = paste(
      "Soma do preju\u00edzo p\u00fablico e privado declarado no S2ID. Zero significa",
      "'nenhum desastre reconhecido no ano', e n\u00e3o 'desastre sem preju\u00edzo'.")
  ),

  comparecimento_eleitoral = list(
    rotulo = "Comparecimento na elei\u00e7\u00e3o para prefeito",
    unidade = "%",
    tabelas = "16_eleicoes",
    precisa = c("tse_comparecimento_prefeitura_i", "tse_eleitores_aptos_prefeitura_i"),
    calcular = function(d) {
      100 * d$tse_comparecimento_prefeitura_i / d$tse_eleitores_aptos_prefeitura_i
    },
    interpretacao = "S\u00f3 existe em ano de elei\u00e7\u00e3o municipal, e s\u00f3 de primeiro turno."
  ),

  esforco_proprio_saude = list(
    rotulo = "Sa\u00fade paga com recursos pr\u00f3prios",
    unidade = "%",
    tabelas = "10_saude",
    precisa = c("ieps_despesa_saude_recursos_proprios_per_capita_brl2023",
                "ieps_despesa_saude_total_per_capita_brl2023"),
    calcular = function(d) {
      100 * d$ieps_despesa_saude_recursos_proprios_per_capita_brl2023 /
        d$ieps_despesa_saude_total_per_capita_brl2023
    },
    interpretacao = paste(
      "Quanto da despesa em sa\u00fade sai do caixa do pr\u00f3prio munic\u00edpio, e n\u00e3o de",
      "transfer\u00eancia federal ou estadual.")
  ),

  desmatamento_relativo = list(
    rotulo = "\u00c1rea desmatada sobre a \u00e1rea do munic\u00edpio",
    unidade = "raz\u00e3o",
    tabelas = "03_meio_ambiente",
    precisa = "area_desmatada_sobre_area_municipio_razao",
    calcular = function(d) d$area_desmatada_sobre_area_municipio_razao,
    interpretacao = paste(
      "Passa de 1 em alguns casos porque numerador e denominador v\u00eam de fontes",
      "diferentes (PRODES e IBGE), com recortes territoriais que n\u00e3o coincidem",
      "exatamente.")
  ),

  vulnerabilidade_social = list(
    rotulo = "\u00cdndice de Vulnerabilidade Social",
    unidade = "\u00edndice de 0 a 1",
    tabelas = "05_sociedade",
    precisa = "ivs_idx",
    calcular = function(d) d$ivs_idx,
    interpretacao = paste(
      "Quanto maior, pior. Medido s\u00f3 nos censos de 2000 e 2010: a dimens\u00e3o",
      "replica o valor nos anos entre eles, e a tabela de fonte",
      "05_sociedade/atlas_ivs guarda apenas as duas medi\u00e7\u00f5es reais.")
  ),

  ideb = list(
    rotulo = "IDEB do munic\u00edpio",
    unidade = "escore de 0 a 10",
    tabelas = "09_educacao",
    precisa = "ideb_nota_municipio_idx",
    calcular = function(d) d$ideb_nota_municipio_idx,
    interpretacao = paste(
      "Divulgado a cada dois anos, nos anos \u00edmpares. A dimens\u00e3o propaga cada",
      "divulga\u00e7\u00e3o para o ano par seguinte; a fonte 09_educacao/ideb guarda s\u00f3",
      "os anos de divulga\u00e7\u00e3o.")
  )
)

#' Catálogo de indicadores
#'
#' @return Um `tibble` com um indicador por linha.
#' @export
#' @examples
#' mape_indicadores()
mape_indicadores <- function() {
  tibble::as_tibble(do.call(rbind, lapply(names(.indicadores), function(nm) {
    ind <- .indicadores[[nm]]
    data.frame(
      indicador = nm, rotulo = ind$rotulo, unidade = ind$unidade,
      tabelas = paste(ind$tabelas, collapse = ", "),
      precisa = paste(ind$precisa, collapse = ", "),
      interpretacao = ind$interpretacao, stringsAsFactors = FALSE)
  })))
}

#' Calcula indicadores
#'
#' Baixa as tabelas necessárias, junta e calcula. Se você já tem os dados na
#' mão, passe-os em `dados` e nada é baixado.
#'
#' @param quais Nomes dos indicadores. `NULL` calcula todos.
#' @param dados Data frame com as colunas necessárias. `NULL` baixa e junta.
#' @param anos Vetor de anos.
#' @param uf Sigla ou vetor de siglas de UF.
#' @param municipios Vetor de nomes ou códigos.
#' @param territorio Se `TRUE`, traz nome do município e UF.
#' @param insumos Se `TRUE`, devolve também as colunas usadas na conta, para que
#'   ela seja conferível.
#' @return Um `tibble` com `id_municipio`, `ano` e uma coluna por indicador.
#' @export
#' @examples
#' \donttest{
#' mape_calcular("taxa_homicidios", anos = 2019, uf = "RJ", territorio = TRUE)
#' }
mape_calcular <- function(quais = NULL, dados = NULL, anos = NULL, uf = NULL,
                          municipios = NULL, territorio = FALSE,
                          insumos = FALSE) {
  if (is.null(quais)) quais <- names(.indicadores)
  desconhecidos <- setdiff(quais, names(.indicadores))
  if (length(desconhecidos)) {
    cli::cli_abort(c(
      "Indicador desconhecido: {.val {desconhecidos}}.",
      ">" = "Veja o cat\u00e1logo com {.run MAPEmunicipios::mape_indicadores()}."))
  }

  precisa <- unique(unlist(lapply(.indicadores[quais], `[[`, "precisa")))

  if (is.null(dados)) {
    tabelas <- unique(unlist(lapply(.indicadores[quais], `[[`, "tabelas")))
    partes <- lapply(tabelas, function(t) {
      mape_ler(t, anos = anos, uf = uf, municipios = municipios, quieto = TRUE)
    })
    names(partes) <- tabelas
    dados <- mape_juntar(partes, tipo = "full", quieto = TRUE)
  }

  faltando <- setdiff(precisa, names(dados))
  if (length(faltando)) {
    culpados <- quais[vapply(quais, function(q) {
      any(.indicadores[[q]]$precisa %in% faltando)
    }, logical(1))]
    cli::cli_abort(c(
      "Faltam colunas para calcular {.val {culpados}}.",
      "x" = "Ausentes: {.field {faltando}}",
      "i" = "Uma coluna que sumiu \u00e9 um indicador que mudou de defini\u00e7\u00e3o, n\u00e3o um NA."))
  }

  chaves <- intersect(c("id_municipio", "ano"), names(dados))
  saida <- dados[, chaves, drop = FALSE]
  for (q in quais) {
    v <- .indicadores[[q]]$calcular(dados)
    # Divisão por zero vira NA. Um Inf atravessa qualquer média sem reclamar e
    # contamina o resultado em silêncio.
    v[is.infinite(v)] <- NA_real_
    saida[[q]] <- v
  }
  if (insumos) {
    saida <- cbind(saida, dados[, setdiff(precisa, chaves), drop = FALSE])
  }
  if (territorio) saida <- mape_com_territorio(saida)
  tibble::as_tibble(saida)
}

#' Ranking de municípios por um indicador
#'
#' O atalho para a pergunta mais comum de quem escreve reportagem: quais são os
#' municípios com maior ou menor valor.
#'
#' O argumento `populacao_minima` existe por um motivo estatístico e não de
#' conveniência. Numa taxa por 100 mil habitantes, um único caso em município de
#' 3 mil pessoas produz 33 por 100 mil — e qualquer ranking sem piso
#' populacional vira uma lista de municípios minúsculos com um evento cada.
#'
#' @param indicador Nome do indicador.
#' @param ano Ano. `NULL` usa o mais recente com dado.
#' @param n Quantos municípios devolver.
#' @param maiores Se `FALSE`, devolve os menores.
#' @param uf Restringe a uma ou mais UFs.
#' @param populacao_minima Piso populacional.
#' @return Um `tibble` ordenado.
#' @export
#' @examples
#' \donttest{
#' mape_ranking("taxa_homicidios", ano = 2019, populacao_minima = 100000)
#' }
mape_ranking <- function(indicador, ano = NULL, n = 10, maiores = TRUE,
                         uf = NULL, populacao_minima = 0) {
  if (length(indicador) != 1) cli::cli_abort("Passe um indicador por vez.")

  pop <- mape_ler("02_populacao", anos = ano, uf = uf, quieto = TRUE)
  pop <- pop[, c("id_municipio", "ano", "populacao_residente_i")]

  ind <- .indicadores[[indicador]]
  if (is.null(ind)) {
    cli::cli_abort(c("Indicador desconhecido: {.val {indicador}}.",
                     ">" = "Veja {.run MAPEmunicipios::mape_indicadores()}."))
  }
  tabelas <- setdiff(ind$tabelas, "02_populacao")
  partes <- c(list(populacao = pop),
              stats::setNames(lapply(tabelas, function(t)
                mape_ler(t, anos = ano, uf = uf, quieto = TRUE)), tabelas))
  d <- mape_juntar(partes, tipo = "full", quieto = TRUE)

  r <- mape_calcular(indicador, dados = d)
  r <- merge(r, pop, by = c("id_municipio", "ano"), all.x = TRUE)
  r <- r[!is.na(r[[indicador]]), , drop = FALSE]

  if (populacao_minima > 0) {
    r <- r[!is.na(r$populacao_residente_i) &
             r$populacao_residente_i >= populacao_minima, , drop = FALSE]
  }
  if (is.null(ano)) {
    ultimo <- max(r$ano, na.rm = TRUE)
    r <- r[r$ano == ultimo, , drop = FALSE]
  }
  if (!nrow(r)) {
    cli::cli_abort(c("Nenhum munic\u00edpio com dado para {.val {indicador}}.",
                     "i" = "Tente outro ano, ou um piso populacional menor."))
  }

  r <- r[order(r[[indicador]], decreasing = maiores), ]
  r <- utils::head(r, n)
  r <- mape_com_territorio(r)
  tibble::as_tibble(r[, c("id_municipio", "nome_municipio", "sigla_uf", "ano",
                          indicador, "populacao_residente_i")])
}
