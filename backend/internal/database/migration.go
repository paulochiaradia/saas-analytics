package database

import (
	"errors"
	"fmt"
	"log"

	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/postgres"
	_ "github.com/golang-migrate/migrate/v4/source/file"
)

// RunAutoMigrations aplica o padrão Facade para esconder a complexidade da engine de migração
func RunAutoMigrations(dbURL string) error {
	log.Println("Iniciando verificação de migrations...")

	// Aponta para a pasta onde os arquivos .sql estão (relativo à raiz de execução)
	m, err := migrate.New("file://migrations", dbURL)
	if err != nil {
		return fmt.Errorf("erro ao inicializar a engine de migrations: %w", err)
	}
	defer m.Close()

	if err := m.Up(); err != nil {
		if errors.Is(err, migrate.ErrNoChange) {
			log.Println("Nenhuma nova migration para aplicar. Banco atualizado.")
			return nil
		}
		return fmt.Errorf("erro ao executar migrations Up: %w", err)
	}

	log.Println("Migrations aplicadas com sucesso!")
	return nil
}
