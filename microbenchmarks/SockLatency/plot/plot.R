# List of required packages
required_packages <- c("dplyr", "ggplot2", "ggbeeswarm", "lubridate", "stringr")

# Function to install missing packages
install_if_missing <- function(packages) {
  installed_packages <- rownames(installed.packages())
  for (pkg in packages) {
    if (!pkg %in% installed_packages) {
      install.packages(pkg, repos = "https://cloud.r-project.org/")
    }
  }
}

# Install missing packages
install_if_missing(required_packages)

# Load required packages
library(dplyr)
library(lubridate)
library(stringr)
library(ggplot2)
library(ggbeeswarm)

# Read data
result_dir <- "../results/data"
csv_files <- list.files(
  result_dir, full.names = TRUE,
  pattern = "^[^/]*-[^/]*-[^/]*-[^/]*\\.csv$"
)
df <- lapply(csv_files, function(file) {
  filename <- basename(file)
  parts <- str_split(filename, "-", simplify = TRUE)

  if (length(parts) >= 4) {
    df <- read.csv(file) %>%
      mutate(
        scenario = parts[1],
        instance_type = parts[2],
        timestamp = ymd_hms(parts[3]),
        git_hash = str_remove(parts[4], "\\.csv$")
      )
    return(df)
  } else {
    return(NULL)  # Skip invalid files
  }
}) %>%
  bind_rows()

agg_store_path <- normalizePath("../results/data/results.csv", mustWork = FALSE)
if (nrow(df)) {
  # process combined data & cleanup
  df <- df %>%
    mutate_if(is.character, trimws) %>%
    mutate(
      architecture_id = case_when(
        scenario == "single_instance" & protocol == "inet"  ~ 1,
        scenario == "single_instance" & protocol == "vsock"  ~ 2,
        scenario == "single_instance_proxy" ~ 3,
        scenario == "cross_instance_host2host" ~ 4,
        scenario == "cross_instance_host2enclave" ~ 5,
        scenario == "cross_instance_proxy" ~ 6,
        TRUE ~ NA
      )
    )

  # store the data
  write.csv(df, file = agg_store_path, row.names = FALSE)
  print(paste("Combined data stored to:", agg_store_path))
} else {
  df <- read.csv(agg_store_path, stringsAsFactors = TRUE)
  print(paste("Results read from", agg_store_path))
}

# all plots from the paper were generated via plot.py
# for your own exploration you can use the following code
# via removing the following exit line(s) and adjusting the filters at the end
print("Skipping explorational R plots. The paper figures will be generated via plot.py")
quit()

# ---------------------
# Utility
# ---------------------

# Function to convert bytes to a more readable format
format_bytes <- function(bytes) {
  if (bytes >= 1024^3) {
    return(paste0(round(bytes / 1024^3, 2), "G"))
  } else if (bytes >= 1024^2) {
    return(paste0(round(bytes / 1024^2, 2), "M"))
  } else if (bytes >= 1024) {
    return(paste0(round(bytes / 1024, 2), "K"))
  } else {
    return(paste0(bytes, ""))
  }
}

byte_breaks <- 2^(3:25)
byte_breaks_2 <- byte_breaks[seq(1, length(byte_breaks), 2)]
byte_breaks_4 <- byte_breaks[seq(1, length(byte_breaks), 4)]
# Apply the formatting function to these breaks
byte_labels <- sapply(byte_breaks, format_bytes)
byte_labels_2 <- sapply(byte_breaks_2, format_bytes)
byte_labels_4 <- sapply(byte_breaks_4, format_bytes)

# ---------------------
# Plotting
# ---------------------

# Filering
msg_size_server <- 1024
msg_size_client <- 8
if (!any(df$server.rsp_size == msg_size_server)) {
  msg_size_server <- min(df$server.rsp_size, na.rm = TRUE)
}
if (!any(df$client.msg_size == msg_size_client)) {
  msg_size_client <- min(df$client.msg_size, na.rm = TRUE)
}

# Boxplot (last run c6i)
plot_path <- "../results/img/boxplot.pdf"
ggplot(df |> filter(server.rsp_size == msg_size_server,
                    client.msg_size == msg_size_client,
                    instance_type %in% c("c6i.2xlarge", "c6in.8xlarge")) %>%
  group_by(
    protocol,
    server.buf_size,
    server.rsp_size,
    client.buf_size,
    client.msg_size
  ) %>%
  slice_tail(n = 1) %>%     # Keep only the last occurrence
  ungroup(),
       aes(
         x = protocol,
         ymin = lower_bound,
         lower = q25,
         middle = median,
         upper = q75,
         ymax = upper_bound
       )) +
  geom_boxplot(stat = "identity") +
  ylim(0, NA) + # Ensure y-axis starts at 0
  facet_wrap(~scenario, scales = "free_y") +
  labs(title = "Boxplot of Protocol Data",
       x = "Protocol",
       y = "Latency (Roundtrip) [µs]") +
  # theme_minimal() +
  theme_bw() +
  # theme_classic() +
  theme(
    legend.position = "bottom",
    legend.title = element_blank()
  )
ggsave(plot_path, width = 6, height = 4, dpi = 300)
print(paste("Boxplot saved to:", plot_path))

# Beeswarm plot (c00ler than bars...)
plot_path <- "../results/img/beeswarm.pdf"
ggplot(
  df |> filter(server.rsp_size == msg_size_server,
               client.msg_size == msg_size_client), aes(
    x = protocol
  )
) +
  geom_beeswarm(aes(
    y = median,
    color = protocol,
    shape = "median"
  )) +
  geom_beeswarm(aes(
    y = p99,
    color = protocol,
    shape = "p99"
  )) +
  # geom_beeswarm(aes(
  #   y = p999,
  #   color = protocol,
  #   shape = "p999"
  # )) +
  facet_wrap(~instance_type) +
  labs(
    title = "Roundtrip-Latency by Protocol",
    x = "Protocol", y = "Latency (Roundtrip) [µs]"
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom",
    legend.title = element_blank()
  )
ggsave(plot_path, width = 6, height = 4, dpi = 300)
print(paste("Swarm plot saved to:", plot_path))

# Line plot with p99, p999, and median over client.msg_size
plot_lines_by_msg_size <- function(df, title, file_name, breaks = byte_breaks_4, labels = byte_labels_4) {
  plot_path <- paste0("../results/img/", file_name, ".pdf")
  df_line <- df %>%
    group_by(protocol, client.msg_size, server.rsp_size, instance_type) %>%
    summarise(
      q25 = median(q25),
      median = median(median),
      q75 = median(q75)
    )
  p <- ggplot(df, aes(x = pmax(client.msg_size, server.rsp_size))) +
    geom_point(aes(
      y = p99,
      color = protocol,
      shape = "p99"
    )) +
    geom_point(aes(
      y = median,
      color = protocol,
      shape = "median"
    )) +
    geom_line(
      data = df_line,
      aes(y = median, color = protocol)
    ) +
    geom_ribbon(
      data = df_line,
      aes(ymin = q25, ymax = q75, fill = protocol), alpha = 0.4
    ) +
    facet_wrap(~instance_type) +
    scale_y_continuous(trans = "log2") +
    scale_x_continuous(trans = "log2", breaks = breaks, labels = labels) +
    labs(
      title = title,
      x = "Message Size (log2) [B]",
      y = "Roundtrip-Latency (log2) [µs]"
    ) +
    theme_bw() +
    theme(
      legend.position = "bottom",
      legend.title = element_blank()
    )
  print(p)
  ggsave(plot_path, width = 6, height = 4, dpi = 300)
  print(paste("Line plot saved to:", plot_path))
}

plot_lines_by_msg_size(
  df |> filter(instance_type == "c6i.2xlarge",
               server.rsp_size == client.msg_size),
  "Latency by Message Size (client & server)",
  "lineplot-symetric-c6i.2xlarge"
)
plot_lines_by_msg_size(
  df |> filter(client.msg_size <= 2^17,
               client.msg_size >= 1024,
               instance_type == "c6i.2xlarge",
               server.rsp_size == client.msg_size),
  "Latency by Message Size (client & server)",
  "lineplot-symetric-c6i.2xlarge-cut",
  byte_breaks_2, byte_labels_2
)
plot_lines_by_msg_size(
  df |> filter(server.rsp_size == client.msg_size),
  "Latency by Message Size (client & server)",
  "lineplot-symetric"
)
plot_lines_by_msg_size(
  df |> filter(server.rsp_size == 8),
  "Latency by Message Size (client)",
  "lineplot-asymetric-client"
)
plot_lines_by_msg_size(
  df |> filter(client.msg_size <= 2^17,
               client.msg_size >= 1024,
               instance_type == "c6i.2xlarge",
               server.rsp_size == 8),
  "Latency by Message Size (client)",
  "lineplot-asymetric-client-cut",
  byte_breaks_2, byte_labels_2
)
plot_lines_by_msg_size(
  df |> filter(client.msg_size == 8),
  "Latency by Message Size (server)",
  "lineplot-asymetric-server"
)
plot_lines_by_msg_size(
  df |> filter(server.rsp_size <= 2^17,
               server.rsp_size >= 1024,
               instance_type == "c6i.2xlarge",
               client.msg_size == 8),
  "Latency by Message Size (server)",
  "lineplot-asymetric-server-cut",
  byte_breaks_2, byte_labels_2
)

# Print Summary
print("Summary:")
print(df |>
        group_by(scenario, instance_type) |>
        summarise(n = n(), .groups = "drop"))
print(df |>
        filter(server.rsp_size == msg_size_server,
               client.msg_size == msg_size_client) |>
        group_by(scenario, instance_type) |>
        summarise(n = n(), .groups = "drop"))
