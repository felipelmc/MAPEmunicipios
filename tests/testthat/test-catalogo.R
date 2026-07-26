# O catálogo trabalha sobre dados embutidos, então estes testes rodam sem rede.

test_that("os dados embutidos estão íntegros", {
  expect_equal(nrow(municipios), 5570)
  expect_type(municipios$id_municipio, "character")
  expect_true(all(nchar(municipios$id_municipio) == 7))
  # Zero à esquerda preservado: o Acre começa em 12, mas há UFs cujo código
  # municipal tem sete dígitos só porque o zero está lá.
  expect_false(any(is.na(municipios$id_municipio)))

  expect_gt(nrow(catalogo), 20)
  expect_true(all(catalogo$camada %in% c("dimensao", "fonte")))
  expect_gt(nrow(variaveis), 400)
})

test_that("mape_resolver aceita as grafias que uma pessoa usaria", {
  expect_equal(mape_resolver("10_saude"), "10_saude")
  expect_equal(mape_resolver("saude"), "10_saude")
  expect_equal(mape_resolver("saúde"), "10_saude")
  expect_equal(mape_resolver("Meio Ambiente"), "03_meio_ambiente")
  expect_equal(mape_resolver("educacao/ideb"), "09_educacao/ideb")
})

test_that("mape_resolver falha dizendo para onde ir", {
  expect_error(mape_resolver("nao_existe_isso"), "Não encontrei")
  expect_error(mape_resolver("nao_existe_isso"), "mape_tabelas")
})

test_that("mape_tabelas filtra por camada, eixo e busca", {
  todas <- mape_tabelas()
  expect_equal(nrow(todas), nrow(catalogo))

  fontes <- mape_tabelas(camada = "fonte")
  expect_true(all(fontes$camada == "fonte"))
  expect_lt(nrow(fontes), nrow(todas))

  saude <- mape_tabelas(eixo = "saude")
  expect_true(all(grepl("saude", saude$slug)))

  expect_gt(nrow(mape_tabelas(busca = "vacina")), 0)
})

test_that("mape_eixos conta tabelas e variáveis de cada eixo", {
  e <- mape_eixos()
  expect_gt(nrow(e), 10)
  expect_true(all(c("eixo", "rotulo", "tabelas", "variaveis") %in% names(e)))
  expect_true(all(e$tabelas >= 1))
  # A soma das variáveis por eixo tem que fechar com o dicionário inteiro.
  expect_equal(sum(e$variaveis), sum(!is.na(variaveis$dimensao)))
})

test_that("mape_variaveis exige todos os termos da busca", {
  cob <- mape_variaveis("cobertura")
  cob_vac <- mape_variaveis("cobertura vacinal")
  expect_lt(nrow(cob_vac), nrow(cob))
  expect_gt(nrow(cob_vac), 0)
})

test_that("mape_variaveis de uma dimensão inclui as fontes dela", {
  so_dim <- mape_variaveis(tabela = "09_educacao/ideb")
  com_fontes <- mape_variaveis(tabela = "09_educacao")
  expect_gt(nrow(com_fontes), nrow(so_dim))
  expect_true(all(so_dim$tabela == "09_educacao/ideb"))
})

test_that("mape_sobre sugere alternativas quando erra o nome", {
  expect_error(mape_sobre("pib_per_capta"), "Não encontrei")
  # Não usa expect_silent porque a função imprime de propósito, via cli.
  expect_no_error(suppressMessages(mape_sobre("pib_per_capita_brl2023")))
})

test_that("mape_sobre devolve a linha do dicionário invisivelmente", {
  linha <- suppressMessages(mape_sobre("ivs_idx"))
  expect_equal(nrow(linha), 1)
  expect_equal(linha$nome_canonico, "ivs_idx")
})

test_that("toda variável tem sufixo do vocabulário fechado", {
  # É esta regra que permite a validação provar que uma coluna _pct está entre
  # 0 e 100. Se ela quebrar, o vocabulário deixou de valer alguma coisa.
  suf <- "_(i|pct|prop|razao|p100k|p1k|p100dom|brl_nominal|brl2023|km|km2|idx|cat)$"
  isento <- "^(flag_|ano_ref_|nome_|sigla_|id_|numero_tse_|centroide_|ddd$|adapta_id_|ano$|turno_)"
  fora <- variaveis$nome_canonico[
    !grepl(suf, variaveis$nome_canonico) &
      !grepl(isento, variaveis$nome_canonico) &
      !variaveis$nome_canonico %in% c("id_municipio", "ano")]
  expect_equal(fora, character(0))
})
