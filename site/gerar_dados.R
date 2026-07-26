# Dados para as visualizações do site ----------------------------------------
#
# O site é estático: nada de servidor, nada de Shiny. As visualizações
# interativas rodam no navegador a partir destes arquivos JSON.
#
# O critério para o que entra: tudo é agregado, e o total precisa caber em
# poucas centenas de kilobytes. Quem quiser o dado inteiro usa o pacote — a
# página existe para mostrar o que dá para fazer, não para substituir o R.
#
# Rodar com:  MAPE_ETL_RAIZ=~/Desktop/MAPEmunicipios-ETL Rscript site/gerar_dados.R

suppressPackageStartupMessages({
  library(MAPEmunicipios)
  library(jsonlite)
})

destino <- "site/dados"
dir.create(destino, recursive = TRUE, showWarnings = FALSE)

grava <- function(x, nome) {
  arq <- file.path(destino, paste0(nome, ".json"))
  write_json(x, arq, auto_unbox = TRUE, digits = 4, na = "null")
  message(sprintf("%-24s %6.1f KB", basename(arq), file.size(arq) / 1024))
}

# --- 1. Catálogo e dicionário ------------------------------------------------

cat_tab <- as.data.frame(MAPEmunicipios::catalogo)
cat_tab$descricao <- substr(cat_tab$descricao, 1, 400)
grava(cat_tab[, c("slug", "camada", "dimensao", "nome_publicado", "descricao",
                  "linhas", "colunas", "municipios", "ano_min", "ano_max",
                  "fonte_original", "periodicidade_fonte", "granularidade")],
      "catalogo")

vars <- as.data.frame(MAPEmunicipios::variaveis)
vars$descricao <- substr(vars$descricao, 1, 300)
grava(vars[, c("nome_canonico", "tabela", "dimensao", "descricao", "unidade",
               "tipo", "minimo", "maximo", "pct_na")], "variaveis")

grava(as.data.frame(mape_eixos()), "eixos")

# --- 2. Série das capitais ---------------------------------------------------
#
# Vinte e sete municípios que qualquer pessoa reconhece, com quatro indicadores
# ao longo do tempo. É o que alimenta o gráfico de linhas da página inicial.

cap <- as.data.frame(MAPEmunicipios::amostra_capitais)
cap$taxa_homicidios <- with(cap, sim_obitos_homicidio_i / populacao_residente_i * 1e5)
cap <- cap[, c("id_municipio", "nome_municipio", "sigla_uf", "nome_regiao", "ano",
               "populacao_residente_i", "pib_per_capita_brl2023",
               "taxa_homicidios", "ieps_cobertura_esf_pct",
               "ieps_despesa_saude_total_per_capita_brl2023")]
names(cap) <- c("id", "municipio", "uf", "regiao", "ano", "populacao",
                "pib_pc", "homicidios", "cobertura_esf", "gasto_saude")
cap <- cap[cap$ano >= 2000, ]
grava(cap, "capitais")

# --- 3. Agregado por UF ------------------------------------------------------
#
# A mediana municipal por UF, e não a média: com municípios de 800 a 12 milhões
# de habitantes, a média é puxada pelas capitais e descreve mal o estado.

anos_alvo <- c(2010, 2015, 2019, 2021)
pop <- mape_ler("02_populacao", anos = anos_alvo, quieto = TRUE)
seg <- mape_ler("13_seguranca", anos = anos_alvo, quieto = TRUE)
eco <- mape_ler("04_economia", anos = anos_alvo, quieto = TRUE)
sau <- mape_ler("10_saude", anos = anos_alvo, quieto = TRUE)

d <- merge(pop[, c("id_municipio", "ano", "populacao_residente_i")],
           seg[, c("id_municipio", "ano", "sim_obitos_homicidio_i")],
           by = c("id_municipio", "ano"), all = TRUE)
d <- merge(d, eco[, c("id_municipio", "ano", "pib_per_capita_brl2023")],
           by = c("id_municipio", "ano"), all = TRUE)
d <- merge(d, sau[, c("id_municipio", "ano", "ieps_cobertura_esf_pct")],
           by = c("id_municipio", "ano"), all = TRUE)
d <- mape_com_territorio(d)
d$taxa_homicidios <- d$sim_obitos_homicidio_i / d$populacao_residente_i * 1e5

med <- function(v) if (all(is.na(v))) NA_real_ else round(stats::median(v, na.rm = TRUE), 2)
por_uf <- do.call(rbind, lapply(split(d, list(d$sigla_uf, d$ano), drop = TRUE), function(g) {
  data.frame(
    uf = g$sigla_uf[1], regiao = g$nome_regiao[1], ano = g$ano[1],
    municipios = nrow(g),
    populacao = sum(g$populacao_residente_i, na.rm = TRUE),
    homicidios_mediana = med(g$taxa_homicidios),
    pib_pc_mediana = med(g$pib_per_capita_brl2023),
    cobertura_esf_mediana = med(g$ieps_cobertura_esf_pct),
    stringsAsFactors = FALSE)
}))
rownames(por_uf) <- NULL
grava(por_uf, "por_uf")

# --- 4. Cobertura temporal de cada eixo --------------------------------------
#
# Quantos municípios cada tabela cobre, ano a ano. É o gráfico que responde
# "posso usar isso para o meu recorte?" antes de qualquer download.

cob <- do.call(rbind, lapply(cat_tab$slug[cat_tab$camada == "dimensao"], function(s) {
  x <- mape_ler(s, quieto = TRUE)
  if (!"ano" %in% names(x)) return(NULL)
  chaves <- intersect(c("id_municipio", "ano"), names(x))
  dados <- setdiff(names(x), chaves)
  tem <- rowSums(!is.na(x[, dados, drop = FALSE])) > 0
  agg <- tapply(x$id_municipio[tem], x$ano[tem], function(v) length(unique(v)))
  data.frame(tabela = s, ano = as.integer(names(agg)),
             municipios = as.integer(agg), stringsAsFactors = FALSE)
}))
cob$cobertura_pct <- round(100 * cob$municipios / 5570, 1)
grava(cob, "cobertura")

# --- 5. Ranking de exemplo ---------------------------------------------------

rk <- as.data.frame(mape_ranking("taxa_homicidios", ano = 2019, n = 20,
                                 populacao_minima = 100000))
grava(rk, "ranking_homicidios_2019")

# --- 6. Resumo geral ---------------------------------------------------------

grava(list(
  municipios = 5570L,
  ano_inicio = 1989L, ano_fim = 2024L,
  eixos = nrow(mape_eixos()),
  tabelas = nrow(cat_tab),
  tabelas_dimensao = sum(cat_tab$camada == "dimensao"),
  tabelas_fonte = sum(cat_tab$camada == "fonte"),
  variaveis = nrow(vars),
  linhas_maior = max(cat_tab$linhas),
  gerado_em = format(Sys.Date(), "%Y-%m-%d")
), "resumo")

message("\npronto.")
