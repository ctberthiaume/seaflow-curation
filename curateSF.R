#!/usr/bin/env Rscript

find_notebook <- function(args) {
  script_path <- args[grep("^--file=", args)]
  script_path <- sub("^--file=", "", script_path)
  if (length(script_path) == 0) {
    stop("no markdown notebook found")
  }
  script_dir <- normalizePath(dirname(script_path))
  nb_path <- paste0(tools::file_path_sans_ext(script_path), ".Rmd")
  return(nb_path)
}

# --------------------------------------------------------------------------- #
# MAIN                                                                        #
# --------------------------------------------------------------------------- #
main <- function() {
  markdown_file <- find_notebook(commandArgs(trailingOnly=FALSE))
  parser <- optparse::OptionParser(
    usage = "usage: curateSF.R db config_file outlier_output_file html_output_file",
    description = "Curate a cruise, create an outlier table TSV file and report HTML file"
  )
  p <- optparse::parse_args2(parser)

  if (length(p$args) != 4) {
    optparse::print_help(parser)
    quit(save="no")
  } else {
    db <- p$args[1]
    config_file <- p$args[2]
    out_file <- p$args[3]
    html_file <- p$args[4]
    if (!file.exists(markdown_file)) {
      stop(paste0(markdown_file, " does not exist"), call. = FALSE)
    }
    if (!file.exists(db)) {
      stop(paste0(db, " does not exist"), call. = FALSE)
    }
    if (!file.exists(config_file)) {
      stop(paste0(config_file, " does not exist"), call. = FALSE)
    }
  }

  print(paste0("using popcycle version ", packageVersion("popcycle")))
  render_params <- list(
    db=db,
    curation_config_path=config_file,
    save_path=out_file
  )
  print(render_params)

  # See https://bookdown.org/yihui/rmarkdown-cookbook/working-directory.html
  # If not explicitly set, the working directory for all code chunks will be
  # the directory that contains this .Rmd file. Switch to the working directory
  # of this script to match normal CLI semantics.
  working_dir <- getwd()

  # See https://pkgs.rstudio.com/rmarkdown/reference/render.html
  # To avoid any intermediate file path or file name collisions, create two
  # temp dirs for output_file and intermediates_dir.
  tmp_dir <- tempdir()
  output_dir <- file.path(tmp_dir, "output_dir")
  intermediates_dir <- file.path(tmp_dir, "intermediates_dir")
  dir.create(output_dir)
  dir.create(intermediates_dir)
  print(paste0("output_dir = ", output_dir))
  print(paste0("intermediates_dir = ", intermediates_dir))

  # https://bookdown.org/yihui/rmarkdown-cookbook/rmarkdown-render.html
  # User xfun::Rscript_call to completely isolate the render environment
  # from this environment
  xfun::Rscript_call(
    rmarkdown::render,
    list(
      input = markdown_file,
      output_file = basename(html_file),
      output_dir = output_dir,
      intermediates_dir = intermediates_dir,
      knit_root_dir = working_dir,
      params = render_params
    )
  )

  # Copy the output file to its final location
  print(paste0("copying ", file.path(output_dir, basename(html_file)), " to ", html_file))
  copy_status <- file.copy(file.path(output_dir, basename(html_file)), html_file, overwrite = TRUE)
  if (!copy_status) {
    stop("copy failed")
  }
}

main()
