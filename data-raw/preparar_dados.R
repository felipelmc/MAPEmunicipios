# Preparação dos dados embutidos no pacote -----------------------------------
#
# O pacote embute três coisas leves e baixa o resto do release. O critério é
# simples: entra o que é preciso para o pacote FUNCIONAR antes de qualquer
# download — resolver o nome de um município, listar as tabelas disponíveis,
# procurar uma variável.
#
# O que NÃO entra é o dado em si. Embutir 72 MB de painel num pacote R seria
# hostil para instalar e ficaria velho a cada release do ETL.
#
# Rodar com:  Rscript data-raw/preparar_dados.R
#
# Fonte: /Users/felipelmc/Projects/MAPEmunicipios-ETL (repositório do ETL).

ETL <- Sys.getenv("MAPE_ETL_RAIZ", "~/Desktop/MAPEmunicipios-ETL")
ETL <- path.expand(ETL)
if (!dir.exists(ETL)) {
  stop("Repositório do ETL não encontrado em ", ETL, ".\n",
       "Defina MAPE_ETL_RAIZ apontando para ele.", call. = FALSE)
}

suppressPackageStartupMessages({
  library(arrow)
})

ler <- function(rel) as.data.frame(read_parquet(file.path(ETL, rel)))

# --- 1. Diretório de municípios ---------------------------------------------
#
# 5.570 linhas. É a espinha dorsal: traz as equivalências entre os vários
# códigos municipais e a hierarquia territorial inteira. Sem ele, buscar
# "Rio de Janeiro" exigiria baixar alguma tabela primeiro.

dir_bruto <- ler("dados/fonte/00_diretorios/municipios.parquet")

manter <- intersect(
  c("id_municipio", "id_municipio_6", "id_municipio_tse", "nome_municipio",
    "sigla_uf", "nome_uf", "nome_regiao", "nome_mesorregiao",
    "nome_microrregiao", "nome_regiao_imediata", "nome_regiao_intermediaria",
    "capital_uf", "amazonia_legal", "semiarido", "area_km2", "ano_instalacao"),
  names(dir_bruto))

municipios <- dir_bruto[, manter, drop = FALSE]
municipios <- municipios[order(municipios$id_municipio), ]
rownames(municipios) <- NULL

# Coluna de busca: minúscula, sem acento, para casar "sao paulo" com
# "São Paulo" sem obrigar quem procura a acertar o acento.
sem_acento <- function(s) {
  de   <- "áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ"
  para <- "aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC"
  tolower(chartr(de, para, s))
}
municipios$busca <- sem_acento(municipios$nome_municipio)

message("municipios: ", nrow(municipios), " x ", ncol(municipios))

# --- 2. Catálogo de tabelas -------------------------------------------------

tabelas <- utils::read.csv(file.path(ETL, "dicionario", "tabelas.csv"),
                           stringsAsFactors = FALSE, encoding = "UTF-8")
inventario <- utils::read.csv(
  file.path(ETL, "dist", "v1.0.0", "INVENTARIO.csv"),
  stringsAsFactors = FALSE, encoding = "UTF-8")

catalogo <- merge(inventario, tabelas, by.x = "slug", by.y = "slug_tabela",
                  all.x = TRUE)
catalogo <- catalogo[, c(
  "slug", "camada", "dimensao", "nome_publicado", "descricao",
  "linhas", "colunas", "municipios", "ano_min", "ano_max", "mb",
  "fonte_original", "fonte_extracao", "link", "licenca",
  "periodicidade_fonte", "granularidade", "regra_preenchimento_temporal",
  "observacoes")]
catalogo <- catalogo[order(catalogo$camada != "dimensao", catalogo$slug), ]
rownames(catalogo) <- NULL

message("catalogo: ", nrow(catalogo), " tabelas")

# --- 3. Dicionário de variáveis ---------------------------------------------

variaveis <- utils::read.csv(file.path(ETL, "dicionario", "variaveis.csv"),
                             stringsAsFactors = FALSE, encoding = "UTF-8")
variaveis <- variaveis[, intersect(c(
  "tabela", "dimensao", "nome_canonico", "descricao", "unidade", "escala",
  "tipo", "dominio_valido", "pct_na", "minimo", "maximo", "problema",
  "nome_legado"), names(variaveis))]
variaveis <- variaveis[!is.na(variaveis$tabela), ]
variaveis <- variaveis[order(variaveis$tabela, variaveis$nome_canonico), ]
rownames(variaveis) <- NULL

variaveis$busca <- sem_acento(paste(variaveis$nome_canonico,
                                    variaveis$descricao))

message("variaveis: ", nrow(variaveis))

# --- 4. Eixos temáticos -----------------------------------------------------

dimensoes <- utils::read.csv(file.path(ETL, "dicionario", "dimensoes.csv"),
                             stringsAsFactors = FALSE, encoding = "UTF-8")
message("dimensoes: ", nrow(dimensoes))

# --- 5. Amostra para exemplo e para o site ----------------------------------
#
# Um recorte pequeno que permite os exemplos da documentação rodarem sem rede,
# e que alimenta as visualizações do site. Vinte e sete capitais, para que o
# exemplo seja reconhecível por qualquer pessoa.

capitais <- c(
  "1100205", "1200401", "1302603", "1400100", "1501402", "1600303", "1721000",
  "2111300", "2211001", "2304400", "2408102", "2507507", "2611606", "2704302",
  "2800308", "2927408", "3106200", "3205309", "3304557", "3550308", "4106902",
  "4205407", "4314902", "5002704", "5103403", "5208707", "5300108")

partes <- list(
  ler("dados/dimensao/02_populacao.parquet"),
  ler("dados/dimensao/04_economia.parquet")[, c("id_municipio", "ano",
                                                "pib_brl2023", "pib_per_capita_brl2023")],
  ler("dados/dimensao/13_seguranca.parquet")[, c("id_municipio", "ano",
                                                 "sim_obitos_homicidio_i")],
  ler("dados/dimensao/10_saude.parquet")[, c("id_municipio", "ano",
                                             "ieps_cobertura_esf_pct",
                                             "ieps_despesa_saude_total_per_capita_brl2023")]
)
partes <- lapply(partes, function(p) p[p$id_municipio %in% capitais, ])

amostra_capitais <- Reduce(function(a, b) merge(a, b, by = c("id_municipio", "ano"),
                                                all = TRUE), partes)
amostra_capitais <- merge(
  municipios[municipios$id_municipio %in% capitais,
             c("id_municipio", "nome_municipio", "sigla_uf", "nome_regiao")],
  amostra_capitais, by = "id_municipio")
amostra_capitais <- amostra_capitais[
  order(amostra_capitais$id_municipio, amostra_capitais$ano), ]
rownames(amostra_capitais) <- NULL

message("amostra_capitais: ", nrow(amostra_capitais), " x ", ncol(amostra_capitais))

# --- Gravação ---------------------------------------------------------------

dir.create("data", showWarnings = FALSE)
save(municipios, file = "data/municipios.rda", compress = "xz")
save(catalogo, file = "data/catalogo.rda", compress = "xz")
save(variaveis, file = "data/variaveis.rda", compress = "xz")
save(dimensoes, file = "data/dimensoes.rda", compress = "xz")
save(amostra_capitais, file = "data/amostra_capitais.rda", compress = "xz")

tam <- sum(file.info(list.files("data", full.names = TRUE))$size) / 1024^2
message("\ndata/ ocupa ", round(tam, 2), " MB")
