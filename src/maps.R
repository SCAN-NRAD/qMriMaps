library(dplyr)
library(ggpubr)
library(reshape2)
library(grid)
library(scales)
library(ggrepel)
library(stringr)
#install.packages("remotes")
#remotes::install_github("LCBC-UiO/ggseg", build_vignettes = FALSE)
library(ggseg)


theme_set(theme_classic())

args <- commandArgs(trailingOnly = TRUE)
if(length(args) > 0) {
  OUT_DIR <- args[1]
  MAPS <- unlist(strsplit(args[2], ','))
} else {
  OUT_DIR <- '/tmp/perf-test/results/'
  MAPS <- c('rBV', 'rBF')
}


plot_brain_stats <- function(stats, subject, metric, scale_limits = c(NA, NA), fix_gradient_scale = c(NA)) {
  names(stats) <- gsub('\\.', '_', names(stats))
  names(stats) <- gsub('_Thalamus_Proper', '_Thalamus-Proper', names(stats))
  names(stats) <- gsub('Left_', 'Left-', names(stats))
  names(stats) <- gsub('Right_', 'Right-', names(stats))
  
  roi_names <- names(stats)
  cortical_metrics <- roi_names[grepl('^(lh|rh)', roi_names, perl=TRUE)]
  subcortical_metrics <- roi_names[roi_names %in% aseg$label]

  stats_subj <- stats[stats$SUBJECT == subject, ]
  stats_cortical_subj <- select(stats_subj, c(cortical_metrics))
  stats_subcortical_subj <- select(stats_subj, c(subcortical_metrics))
  
  # remove ROI with NA
  stats_cortical_subj <- stats_cortical_subj[, !is.na(stats_cortical_subj)]
  stats_subcortical_subj <- stats_subcortical_subj[, !is.na(stats_subcortical_subj)]
  if(length(names(stats_cortical_subj)) == 0) {
    print(sprintf('WARNING all ROI are NA for %s', subject))
    p <- ggplot()+labs(title=subject)+theme(plot.title = element_text(size=12, hjust=0.5), plot.subtitle=element_text(size=8))
    return(p)
  } else {
    df <- data.frame(label = names(stats_cortical_subj), value = unlist(unname(stats_cortical_subj)))
    df_subcortical  <- data.frame(label = names(stats_subcortical_subj), value = unlist(unname(stats_subcortical_subj)))
    
  }
  
  color_gradient <- scale_fill_gradient(low='blue',high='goldenrod', limits=scale_limits)
  if(!is.na(fix_gradient_scale[1])) {
    color_gradient <- scale_fill_gradient2(low='blue', mid='lightgray', high='red', midpoint=fix_gradient_scale[2], limits=c(fix_gradient_scale[1], fix_gradient_scale[3]))
  }

  if(startsWith(subject, 'COHORT mean') | startsWith(subject, 'Correlation')) {
    title_long <- subject
  } else {
    title_long <- subject
  }
  
  p1 <- ggseg(.data=df, mapping=aes(fill=value), color='gray')+
    color_gradient+
    labs(title=title_long, fill = metric)+theme_classic()+
    theme(plot.title = element_text(size=12, hjust=0.5), plot.subtitle=element_text(size=8))
  
  p2 <- ggseg(.data=df_subcortical, atlas=aseg, mapping=aes(fill=value), color='gray', hemisphere = c('left', 'right'))+
    color_gradient+theme_classic()+theme(legend.position='none')
    #labs(fill = metric)+theme_classic()#+theme(plot.title = element_text(size=12, hjust=0.5), plot.subtitle=element_text(size=8))
  
  return(ggarrange(plotlist=list(p1, p2), nrow=1, ncol=2, widths=c(4,1)))
}

plot_all_brain_pdf <- function(stats, metric, filename, scale_limits = c(NA, NA), gradient_center_GM = FALSE) {
  # sort by subject name
  stats <- stats[sort(as.character(stats$SUBJECT), index.return=TRUE)$ix, ]
  
  # calculate cohort mean
  roi_names <- names(stats)
  cortical_metrics <- roi_names[grepl('^(lh|rh|Left.*|Right.*|TotalCortex)', roi_names, perl=TRUE)]
  values <- select(stats, c(cortical_metrics))
  cohort_mean <- colMeans(values, na.rm = TRUE)
  
  fix_gradient_scale_cohort <- c(min(cohort_mean, na.rm=TRUE), mean(stats$TotalCortex), max(cohort_mean, na.rm=TRUE))
  fix_gradient_scale_subject <- c(min(values, na.rm=TRUE), mean(stats$TotalCortex), max(values, na.rm=TRUE))
  
  # add cohort
  cohort_name <- sprintf('COHORT mean (N=%i)', nrow(stats))
  stats$SUBJECT <- as.character(stats$SUBJECT)
  stats[nrow(stats)+1, 'SUBJECT'] <- cohort_name
  stats[stats$SUBJECT == cohort_name, cortical_metrics] <- cohort_mean

  plots = list()
  
  for(idx in c(1:nrow(stats))) {
    fix_gradient_scale <- NA 
    if(gradient_center_GM) {
      if(startsWith(stats[idx, 'SUBJECT'], 'COHORT')) {
        fix_gradient_scale <- fix_gradient_scale_cohort
      } else {
        fix_gradient_scale <- fix_gradient_scale_subject
      }
    }
    
    plots = c(plots, list(plot_brain_stats(stats, stats[idx, 'SUBJECT'], metric, scale_limits, fix_gradient_scale)))
  }
  
  multi.page <- ggarrange(plotlist=plots, nrow=4, ncol=1)
  ggexport(multi.page, filename = paste(OUT_DIR, filename, sep='/'), width=12)
}

for(map in MAPS) {
  for(metric in c('roi_coverage', 'mean')) {
    stats <- read.csv(sprintf('%s/%s_%s.csv', OUT_DIR, map, metric))
    stats_std <- read.csv(sprintf('%s/%s_std.csv', OUT_DIR, map))
    
    if(metric == 'mean') {
      # calc z-scores with respect to totalGM
      stats_zscore <- stats
      stats_zscore[, 2:ncol(stats)] <- (stats[, 2:ncol(stats)] - stats$TotalCortex) / stats_std$TotalCortex
      #write.table(stats_rbv_zscore, file=sprintf('%s/%s_zscore.csv', OUT_DIR, metric), sep=';', na='', row.names=FALSE, quote=FALSE)
      
      plot_all_brain_pdf(stats_zscore, sprintf('%s %s (z-score GM)', map, metric), sprintf('%s_%s_zscore.pdf', map, metric), gradient_center_GM = TRUE)
    }
    
    if(metric == 'roi_coverage') {
      plot_all_brain_pdf(stats, metric, sprintf('%s_%s.pdf', map, metric), scale_limits = c(0, 100))
    } else {
      plot_all_brain_pdf(stats, sprintf('%s %s', map, metric), sprintf('%s_%s.pdf', map, metric), gradient_center_GM = TRUE)
    }
  }
}

