package main

import (
	"fmt"
	"log"
	"net/url"
	"os"

	"github.com/joho/godotenv"
	"github.com/paulochiaradia/saas-analytics/internal/database"
)

func main() {
	// 1. Carrega as variáveis do .env localizado na raiz do projeto
	if err := godotenv.Load("../.env"); err != nil {
		log.Println("Aviso: arquivo .env não encontrado, utilizando variáveis do sistema.")
	}

	// 2. Protege a senha codificando os caracteres especiais (como # e @)
	rawPassword := os.Getenv("POSTGRES_PASSWORD")
	escapedPassword := url.QueryEscape(rawPassword)

	// 3. Monta a string de conexão segura
	dbURL := fmt.Sprintf("postgres://%s:%s@localhost:5432/%s?sslmode=disable",
		os.Getenv("POSTGRES_USER"),
		escapedPassword, // Usamos a senha codificada (ex: Y7k%23p9M...)
		os.Getenv("POSTGRES_DB"),
	)

	// 4. Executa as migrations automaticamente ao subir o sistema
	if err := database.RunAutoMigrations(dbURL); err != nil {
		log.Fatalf("Falha crítica no banco de dados: %v", err)
	}

	log.Println("Backend inicializado e pronto para receber requisições.")
}
