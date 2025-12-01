package com.quickgas.config;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import lombok.extern.slf4j.Slf4j;
import org.flywaydb.core.Flyway;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.flyway.FlywayProperties;
import org.springframework.boot.autoconfigure.jdbc.DataSourceProperties;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

import javax.sql.DataSource;
import java.net.URI;
import java.net.URISyntaxException;

@Slf4j
@Configuration
@EnableConfigurationProperties(FlywayProperties.class)
public class DataSourceConfig {
    
    @Value("${DATABASE_URL:}")
    private String databaseUrl;
    
    @Bean
    @Primary
    public DataSource dataSource() {
        // If DATABASE_URL is provided (Railway format: postgresql://...), parse it
        if (databaseUrl != null && !databaseUrl.isEmpty() && !databaseUrl.startsWith("jdbc:")) {
            try {
                // Handle postgresql:// and postgres:// formats
                String urlToParse = databaseUrl;
                if (urlToParse.startsWith("postgresql://")) {
                    urlToParse = urlToParse.replace("postgresql://", "http://");
                } else if (urlToParse.startsWith("postgres://")) {
                    urlToParse = urlToParse.replace("postgres://", "http://");
                }
                
                URI dbUri = new URI(urlToParse);
                
                String[] userInfo = dbUri.getUserInfo().split(":");
                String username = userInfo[0];
                String password = userInfo.length > 1 ? userInfo[1] : "";
                String host = dbUri.getHost();
                int port = dbUri.getPort() > 0 ? dbUri.getPort() : 5432;
                String path = dbUri.getPath();
                String database = path.startsWith("/") ? path.substring(1) : path;
                
                // Construct JDBC URL
                String jdbcUrl = String.format("jdbc:postgresql://%s:%d/%s", host, port, database);
                
                log.info("Parsed DATABASE_URL: host={}, port={}, database={}, username={}", 
                    host, port, database, username);
                
                // Create HikariCP DataSource directly
                HikariConfig config = new HikariConfig();
                config.setJdbcUrl(jdbcUrl);
                config.setUsername(username);
                config.setPassword(password);
                config.setMaximumPoolSize(10);
                config.setMinimumIdle(5);
                config.setConnectionTimeout(30000);
                config.setDriverClassName("org.postgresql.Driver");
                
                return new HikariDataSource(config);
            } catch (URISyntaxException | ArrayIndexOutOfBoundsException e) {
                log.error("Failed to parse DATABASE_URL: {}", databaseUrl, e);
                throw new IllegalStateException("Invalid DATABASE_URL format. Expected: postgresql://user:password@host:port/database", e);
            }
        } else if (databaseUrl != null && !databaseUrl.isEmpty() && databaseUrl.startsWith("jdbc:")) {
            // Already in JDBC format, use it directly
            log.info("Using DATABASE_URL directly (JDBC format)");
            HikariConfig config = new HikariConfig();
            config.setJdbcUrl(databaseUrl);
            config.setMaximumPoolSize(10);
            config.setMinimumIdle(5);
            config.setConnectionTimeout(30000);
            config.setDriverClassName("org.postgresql.Driver");
            return new HikariDataSource(config);
        }
        
        // Otherwise, use the default configuration from application.yml
        DataSourceProperties properties = new DataSourceProperties();
        return properties.initializeDataSourceBuilder().build();
    }
    
    @Bean(initMethod = "migrate")
    public Flyway flyway(DataSource dataSource, FlywayProperties flywayProperties) {
        return Flyway.configure()
            .dataSource(dataSource)
            .locations(flywayProperties.getLocations().toArray(new String[0]))
            .baselineOnMigrate(flywayProperties.isBaselineOnMigrate())
            .validateOnMigrate(flywayProperties.isValidateOnMigrate())
            .load();
    }
}

