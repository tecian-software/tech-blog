I've covered a fair number of AWS topics in recent posts, so todays post I'll cover some Golang and publish something for the developers. The main thing I'm going to cover is how to dockerize an existing golang application that uses go modules via a multi-stage dockerfile. The first obvious question is, why not just use the golang docker image provided by the good people at google? 

The answer is, its a beefy image because it contains all the needed build tools and compilers to build and manage go applications. One of the nice things about Golang and other compiled languages is that the source code gets compiled to a native executable, so all those build tools are more less redundant once the source code has compiled. That means that we can ditch the large Golang image that we used to build the application for a smaller runtime image. This will drastically reduce the size of the final image, and will save you some storage cost and network time.

For the case of this post, I'm going to use the golang:1.18 build to match the go version that I'm running locally, and then transition into a linux alpine based image. Make sure to change the version of the golang image if you are running a different golang version.

## The Code

I'm going to write a very simple application for this one. Just a basic REST API that has a GET - /health_check and POST - /example. The POST endpoint is going to execute a basic addition, so just swap this out for anything you can think of. I'm also going to be using go modules. If you aren't using go modules already, check out the docs <a href="https://go.dev/blog/using-go-modules">here</a> for a basic intro. Life's too short to be dealing with GO_PATH issues.

First, we initialize our module

```bash
$ go mod init example_app
```

Then create the source code file(s)

```bash
touch main.go Dockerfile
```

Next, import go dependencies. For my API, I'm going to use <a href="">gin-gonic</a>, my person go-to module for lightweight API's. I'm also going to use the <a href="">sirupsen/logrus</a> for logging.

```bash
$ go get github.com/sirupsen/logrus github.com/gin-gonic/gin
```

The source code for the API looks something like the following

```go
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
```

As promised, it's nothing but a dead simple REST API. If you want to test it locally, you can do so using

```bash
$ go run main.go
```

which should start the server on port 8080. 

## The Dockerfile

Once we have the code up and running, its time for the Dockerfile.

```dockerfile
FROM golang:1.18 as build

ENV GO111MODULE=on

WORKDIR /app/server

COPY ./go.mod .
COPY ./go.sum .

RUN go mod download

COPY . .

RUN CGO_ENABLED=0 go build main.go

FROM alpine:latest as server

WORKDIR /app/server

COPY --from=build /app/server/main ./

RUN chmod +x ./main

CMD [ "./main" ]
```

Lets break that down line-by-line. The first few lines are fairly straightforward.

```dockerfile
FROM golang:1.18 as build

ENV GO111MODULE=on

WORKDIR /app/server
```

I pull the latest `golang:1.18` image and create a `/app/server` directory to store the source code. The only thing that may be new is the `GO111MODULE=on` line. What this effectively does is force the usage of go modules, which is needed for historic versions. Technically speaking, everything running go 1.16+ has this enabled by default, but I included it in this case anyway to be explicit. Check out <a href="https://maelvls.dev/go111module-everywhere/">this</a> for a great explanation of what it does and why you may (or may not), need it.

Next it's time to install dependencies. Go modules make this extremely easy, and the following lines do just that.

```dockerfile
COPY ./go.mod .
COPY ./go.sum .

RUN go mod download
```

If you haven't used go modules before, the `go.mod` and `go.sum` files define your dependencies. Running go get or go install adds a reference to the dependency and the version to the go.mod file and go.sum is a checksum which validates that none of the dependencies have been modified when you build. `go mod download` just installs the dependencies defined in `go.mod`.

With dependencies installed, it's time to build our executable

```dockerfile
COPY . .

RUN CGO_ENABLED=0 go build main.go
```

Again, this one should be straightforward. The only gotcha is the `CGO_ENABLED` flag. What is this doing? `CGO_ENABLED` enables something called `cgo`, a nifty piece of tech that allows you to build golang packages that call C code. It's not something many people will have come across if you haven't done this sort of stuff before, but in this case, we need it to be able to run our source code in an alpine OS image. The underlying OS image used in the official golang image is debian based, so if I simply ran `go build` without `cgo`, the resulting executable would not run on alpine OS. `cgo` fixes that i.e. its a cross compiling tool.

At this point it's worth mentioning that there are debates on whether or not usage of `cgo` is best practice. For production code bases, the best thing is generally to not enable `cgo` and just transition from the `golang` to a debian based image. However, debian images are significantly chunkier than alpine, so the final image will be larger. If you are doing this for a personal project on the other hand, the compact image is generally worth it. If you want to read more about `cgo` and some of the issues around build time and performance, check out this post <a href="https://dave.cheney.net/2016/01/18/cgo-is-not-go">here</a>.

Once everything is compiled, we are ready to introduce the next docker stage. Again, this one should be easy

```dockerfile
FROM alpine:latest as server

WORKDIR /app/server

COPY --from=build /app/server/main ./

RUN chmod +x ./main

CMD [ "./main" ]
```

All I'm doing is pulling from the latest alpine image, and copying the source code from the build stage using the `COPY --from` directive. Then, I run a cheeky `chmod` to give exec permissions, and finish with a `CMD` to define the entrypoint (which in this case just points at the built executable).

## Finishing Up

That more or less covers it. Once you have the code and Dockerfile setup, just run 

```bash
$ docker build -t example-app .
$ docker run -p 8080:8080 example-app
```

That will build and start the container on port 8080. From there, switch out any bits of code that you want and deploy.

