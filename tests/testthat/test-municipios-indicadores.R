test_that("mape_buscar_municipio ignora acento e caixa", {
  a <- mape_buscar_municipio("São Paulo", uf = "SP", exato = TRUE)
  b <- mape_buscar_municipio("sao paulo", uf = "SP", exato = TRUE)
  expect_equal(a$id_municipio, b$id_municipio)
  expect_equal(a$id_municipio, "3550308")
})

test_that("mape_buscar_municipio devolve vazio sem inventar", {
  # "Floripa" não é nome oficial de nada. O certo é devolver zero linhas, e não
  # o município mais parecido.
  expect_equal(nrow(mape_buscar_municipio("Floripa")), 0)
})

test_that("mape_resolver_municipio aceita código de 7 e de 6 dígitos", {
  expect_equal(mape_resolver_municipio("3304557"), "3304557")
  expect_equal(mape_resolver_municipio("330455"), "3304557")
})

test_that("mape_resolver_municipio interrompe em nome ambíguo", {
  # Escolher um por conta própria devolveria o município errado em silêncio,
  # que é o pior desfecho possível. Melhor parar e listar.
  expect_error(mape_resolver_municipio("Bom Jesus"), "é o nome de")
  # Com a UF, deixa de ser ambíguo.
  expect_equal(mape_resolver_municipio("Bom Jesus", uf = "PI"), "2201903")
})

test_that("mape_resolver_municipio resolve um vetor misto", {
  r <- mape_resolver_municipio(c("3304557", "São Paulo", "310620"))
  expect_equal(r, c("3304557", "3550308", "3106200"))
})

test_that("mape_municipios filtra por UF e região", {
  ac <- mape_municipios(uf = "AC")
  expect_equal(nrow(ac), 22)
  expect_true(all(ac$sigla_uf == "AC"))

  norte <- mape_municipios(regiao = "Norte")
  expect_true(all(norte$nome_regiao == "Norte"))
  expect_lt(nrow(norte), 5570)
})

test_that("mape_com_territorio não multiplica linhas", {
  x <- data.frame(id_municipio = c("3304557", "3550308"), ano = c(2020L, 2020L),
                  v = c(1, 2), stringsAsFactors = FALSE)
  y <- mape_com_territorio(x)
  expect_equal(nrow(y), 2)
  expect_true(all(c("nome_municipio", "sigla_uf") %in% names(y)))
  # A chave fica à frente, para o objeto ser legível ao imprimir.
  expect_equal(names(y)[1], "id_municipio")
})

test_that("mape_com_territorio exige a coluna de chave", {
  expect_error(mape_com_territorio(data.frame(x = 1)), "id_municipio")
})

test_that("mape_indicadores traz o catálogo com as dependências declaradas", {
  ind <- mape_indicadores()
  expect_gt(nrow(ind), 5)
  expect_true(all(c("indicador", "rotulo", "unidade", "precisa",
                    "interpretacao") %in% names(ind)))
  # Um indicador sem dependência declarada não teria como avisar que quebrou.
  expect_false(any(is.na(ind$precisa) | ind$precisa == ""))
  expect_false(any(is.na(ind$interpretacao) | ind$interpretacao == ""))
})

test_that("todo indicador aponta para variável que existe no dicionário", {
  ind <- mape_indicadores()
  precisa <- unique(trimws(unlist(strsplit(ind$precisa, ","))))
  expect_true(all(precisa %in% variaveis$nome_canonico),
              info = paste("ausentes:",
                           paste(setdiff(precisa, variaveis$nome_canonico),
                                 collapse = ", ")))
})

test_that("mape_calcular nomeia a coluna que falta", {
  vazio <- data.frame(id_municipio = "3304557", ano = 2020L)
  expect_error(mape_calcular("taxa_homicidios", dados = vazio), "Faltam colunas")
})

test_that("mape_calcular recusa indicador desconhecido", {
  expect_error(mape_calcular("nao_existe"), "desconhecido")
})

test_that("mape_calcular acerta a conta e não deixa infinito passar", {
  d <- data.frame(
    id_municipio = c("3304557", "3550308"), ano = c(2020L, 2020L),
    sim_obitos_homicidio_i = c(20, 5),
    populacao_residente_i = c(1000000, 0),
    stringsAsFactors = FALSE)
  r <- mape_calcular("taxa_homicidios", dados = d)
  expect_equal(r$taxa_homicidios[1], 2)
  # Divisão por zero vira NA. Um Inf atravessa qualquer média sem reclamar.
  expect_true(is.na(r$taxa_homicidios[2]))
})

test_that("mape_calcular devolve os insumos quando pedido", {
  d <- data.frame(id_municipio = "3304557", ano = 2020L,
                  sim_obitos_homicidio_i = 20,
                  populacao_residente_i = 1000000, stringsAsFactors = FALSE)
  r <- mape_calcular("taxa_homicidios", dados = d, insumos = TRUE)
  expect_true(all(c("sim_obitos_homicidio_i", "populacao_residente_i") %in% names(r)))
})

test_that("mape_juntar recusa tabela com chave duplicada", {
  a <- data.frame(id_municipio = c("3304557", "3304557"), ano = c(2020L, 2020L),
                  v = 1:2, stringsAsFactors = FALSE)
  b <- data.frame(id_municipio = "3304557", ano = 2020L, w = 9,
                  stringsAsFactors = FALSE)
  expect_error(mape_juntar(a, b, quieto = TRUE), "chaves duplicadas")
})

test_that("mape_juntar recusa tabela sem ano sem autorização", {
  a <- data.frame(id_municipio = "3304557", ano = 2020L, v = 1,
                  stringsAsFactors = FALSE)
  b <- data.frame(id_municipio = "3304557", w = 9, stringsAsFactors = FALSE)
  expect_error(mape_juntar(a, b, quieto = TRUE), "não tem coluna")
  expect_no_error(mape_juntar(a, b, replicar = TRUE, quieto = TRUE))
})

test_that("mape_juntar registra o relatório de cada passo", {
  a <- data.frame(id_municipio = "3304557", ano = 2020L, v = 1,
                  stringsAsFactors = FALSE)
  b <- data.frame(id_municipio = "3304557", ano = 2020L, w = 9,
                  stringsAsFactors = FALSE)
  r <- mape_juntar(a, b, quieto = TRUE)
  rel <- attr(r, "mape_relatorio")
  expect_equal(nrow(rel), 2)
  expect_true(all(c("tabela", "linhas", "colunas") %in% names(rel)))
})
