source("util.R")

# Install missing packages
required_packages <- c(
  "dplyr",
  "tidyr",
  "ggplot2",
  "yaml",
  "ggbeeswarm",
  "patchwork"
)
install_if_missing(required_packages)

# Load required packages
library(dplyr)
library(ggplot2)
library(yaml)
library(tidyr)
library(ggbeeswarm)
library(patchwork)


df <- read_results()

df <- df %>%
  replace_na(list(
    proxy_on = FALSE,
    proxy_so_no_delay = FALSE
  ))

# all plots from the paper were generated via plot.py
# for your own exploration you can use the following code
# via removing the following exit line(s) and adjusting the filters at the end
print("Skipping explorational R plots. The paper figures will be generated via plot.py")
quit()

# ----------------------------
# Plotting
# ----------------------------

generate_plots <- function(df_plot, operation, scenario) {
  n_combinations <- n_distinct(interaction(df_plot$context, df_plot$setup))

  p_tp <- ggplot(
    df_plot,
    aes(x = interaction(context, setup))
  ) +
    geom_bar(aes(
      y = rps,
      fill = interaction(context, setup)
    ), stat = "summary", fun = "mean") +
    facet_grid(pipeline ~ num_clients, labeller = label_both) +
    # facet_wrap(~num_clients) +
    labs(
      title = paste0("Throughput (", operation, ")"),
      x = "Context.Setup",
      y = "Throughput [queries/s]"
    ) +
    theme_bw() +
    theme(
      legend.position = "bottom",
      legend.title = element_blank(),
      legend.box = "vertical",
      legend.spacing.y = unit(0, "cm"),
      axis.text.x = element_blank()
    ) +
    guides(
      fill = guide_legend(ncol = min(n_combinations, 3)),
    )
  print(p_tp)
  img_path <- file.path(img_dir, paste0(operation, "_", scenario, "_tp.pdf"))
  ggsave(
    img_path,
    width = 6,
    height = 4,
    dpi = 300
  )
  print(paste("Plot saved to:", img_path))

  p_l <- ggplot(
    df_plot,
    aes(x = interaction(context, setup))
  ) +
    geom_bar(aes(
      y = avg_latency_ms,
      fill = interaction(context, setup)
    ), stat = "summary", fun = "mean", alpha = 0.4) +
    geom_beeswarm(aes(
      y = p50_latency_ms,
      color = interaction(context, setup),
      shape = "p50"
    )) +
    geom_beeswarm(aes(
      y = p95_latency_ms,
      color = interaction(context, setup),
      shape = "p95"
    )) +
    geom_beeswarm(aes(
      y = min_latency_ms,
      color = interaction(context, setup),
      shape = "min"
    )) +
    facet_grid(pipeline ~ num_clients, labeller = label_both) +
    # facet_wrap(~num_clients) +
    labs(
      title = paste0("Latency (", operation, ")"),
      x = "Context.Setup",
      y = "Latency [ms]"
    ) +
    theme_bw() +
    theme(
      legend.position = "bottom",
      legend.title = element_blank(),
      legend.box = "vertical",
      legend.spacing.y = unit(0, "cm"),
      axis.text.x = element_blank()
    ) +
    guides(
      color = guide_legend(ncol = min(n_combinations, 3), order = 1),
      fill = guide_legend(ncol = min(n_combinations, 3), order = 1),
      shape = guide_legend(ncol = 3, order = 2)
    )
  print(p_l)

  img_path <- file.path(img_dir, paste0(operation, "_", scenario, "_latency.pdf"))
  ggsave(
    img_path,
    width = 6,
    height = 4,
    dpi = 300
  )
  print(paste("Plot saved to:", img_path))

  p <- p_tp + p_l
  print(p)
  img_path <- file.path(img_dir, paste0(operation, "_", scenario, ".pdf"))
  ggsave(
    img_path,
    width = 12,
    height = 4,
    dpi = 300
  )
  print(paste("Plot saved to:", img_path))

}

for (operation in unique(df$op)) {
  generate_plots(
    df_plot = df %>% filter(
      op == operation,
      setup %in% c("direct", "proxied", "cross_instance"),
      num_clients %in% c(31),
      pipeline %in% c(1000)
    ),
    operation = operation,
    scenario = "proxy"
  )

  generate_plots(
    df_plot = df %>% filter(
      op == operation,
      setup %in% c("compact"),
      num_clients %in% c(50),
      pipeline %in% c(64)
    ),
    operation = operation,
    scenario = "compact"
  )
}