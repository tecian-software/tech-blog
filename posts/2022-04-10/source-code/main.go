package main

import (
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	log "github.com/sirupsen/logrus"
)

func New() *gin.Engine {
	// generate new instance of router engine
	r := gin.Default()

	// generate health check endpoint for application
	r.GET("/health_check", func(ctx *gin.Context) {
		log.Debug("received request for health check handler")
		ctx.JSON(http.StatusOK, gin.H{"message": "Service is running"})
	})

	// add POST endpoint to mock functionality
	r.POST("/example", func(ctx *gin.Context) {
		log.Debug("received request to execute sample endpoint")
		var r struct {
			X int `json:"x" binding:"required"`
			Y int `json:"y" binding:"required"`
		}
		// parse request body and raise error if
		// variables cannot be processed/parsed
		if err := ctx.ShouldBind(&r); err != nil {
			log.Error(fmt.Errorf("Unable to execute request: unable to parse request body. %+v", err))
			ctx.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"message": "Invalid request body"})
			return
		}

		ctx.JSON(http.StatusOK, gin.H{"result": r.X + r.Y})
	})

	return r
}

func main() {
	// generate new server engine and start
	router := New()
	router.Run(fmt.Sprintf(":8080"))
}
