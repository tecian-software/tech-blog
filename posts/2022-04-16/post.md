# Building gRPC Apps with Python

Today, I'm going to briefly cover how to get started with gRPC applications using Python and the `grpc` client library. The app I'm going to be building is a spin off of the classic Fibonacci sequence problem, and will have two endpoints, one to generate batches and one to stream values. While it's a trivial application, it should illustrate the key concepts of starting out with gRPC in python and should provide a decent scaffold to build on.

## GRPC Overview

First of, what is gRPC? It stands for Google Remote Procedure Call, and (as the name suggests), its a high-performance RPC protocol developed by google initially released in August of 2016. Conceptually, the easiest way to think about it is an alternative to HTTP REST interfaces i.e. you define some form of target function in your programming language of choice that can be executed via some pre-defined interfaces.

gRPC itself is built on HTTP/2 (also initially developed at google), which in and of itself has some distinct advantages over its predecessor. The main advantage is performance, and its claimed to be 7x faster than HTTP/1.1 in some cases. One of the key differences between HTTP/2 and 1.1 is that HTTP/2 encodes requests/responses in a binary format, whereas HTTP/1.1 uses plain text. This binary framing layer opens up the doors to a lot of new concepts including multiplexing. A single HTTP/2 connection essentially consists of a collection of parallel data streams, each of which contains a series of request/response messages. There's a number of significant advantages to having a single connection containing multiple data streams, and if you want to read more about it, I would suggest the <a href="https://www.digitalocean.com/community/tutorials/http-1-1-vs-http-2-what-s-the-difference">following article</a> from Digital Ocean, which covers some of the key topics nicely.

The major uptick of all of this is that gRPC is (in most cases) faster than traditional REST interfaces, and supports a collection of cool features including native support for client-server and server-client streaming (or both). One important thing to note is that HTTP/2 and HTTP/1.1 are not strictly speaking backwards compatible. However, modern browsers generally all support both protocols and a protocol agreement is reached between client and server at request time to determine which HTTP version to use.

### Protocol Buffers

One key difference between gRPC and REST is how you define services. Traditional REST interfaces are language specific i.e. you pick your programming language, choose a framework and code away. When using gRPC, the service interface is defined using <a href="https://developers.google.com/protocol-buffers/docs/overview">protocol buffers</a> in `.proto` files, which are language neutral. The service interface in this case defines the endpoints that are available (and the type of endpoint), as well as the input and output message structures. Once the protocol buffers are defined, a language-specific protocol buffer compiler is used to construct a language-specific application skeleton code for client and server (know as stubs). The auto-generated stubs essentially define the communication interface between client and server, and all that's left for a developer to do is import the stubs and implement the handler functions to handle the requests.

## Fibonacci Application Code

Lets get started with some python code (I'm running python 3.9 for everything I'm using here). There's a couple of dependencies that need installing first

```bash
$ pip install -U pip grpcio grpcio-tools
```

The `grpcio` library contains the client and server code for the python `gRPC` implementation. `grpcio-tools` contains the protocol buffer compiler that I'll be using to convert the protocol buffers to python stubs. Next I'll define a bit of source code to generate a Fibonacci sequence.

```python
from typing import Generator

def generate_fibonacci(count: int) -> Generator[int, None, None]:
    """Generator used to construct fibonacci
    sequence"""

    a, b = 0, 1
    current_count = 0
    while True:
        yield a
        current_count += 1
        if current_count >= count:
            break
        # increment values
        a, b = b, a + b

```

In a nutshell, the above function generate fibonacci sequence numbers until we reach some set count i.e. `generate_fibonacci(56)` returns the first 56 numbers in the fibonacci sequence. I'm implementing the above as a generator to maximize performance and to maintain a low memory footprint when we start streaming values.

### Protocol Buffers

Now lets write out protocol buffers. First, create a separate directory for the `.proto` files

```bash
$ mkdir protos
```

then generate the proto file

```bash
$ touch protos/fibonacci.proto
```

Copy the following contents into the file

```proto
syntax = "proto3";

service FibonacciService {
    rpc GetSequence (SequenceRequest) returns (SequenceResponse) {}
    rpc StreamSequence (SequenceRequest) returns (stream SequenceElement) {}
}
  
message SequenceRequest {
    int64 count = 1;
}

message SequenceElement {
    int64 element = 1;
    int64 count = 2;
}

message SequenceResponse {
    repeated int64 element = 1;
}

```

Lets break the above down. First, we have the `service FibonacciService` section that defines our gRPC service. Endpoints are added to a service via the `rpc` statement, followed by the endpoint definition.

#### Endpoint 1 - `rpc GetSequence (SequenceRequest) returns (SequenceResponse) {}`

The first endpoint (as defined above) is going to be used to fetch a sequence of Fibonacci sequences. When defining a gRPC endpoint, both the request and response bodies are passed into the endpoint definition. In this case, the service expects a `SequenceRequest` message as the input argument, and returns a `SequenceResponse` message.

The message structures themselves are defined in the same file. In this case, `SequenceRequest` (i.e. the request body) is defined as 

```proto
message SequenceRequest {
    int64 count = 1;
}
```

Note that we are going to use the value for the `count` key as the input to our python function to determine how many Fibonacci sequences numbers to generate. The `SequenceResponse` message (i.e. the response body) is defined as

```proto
message SequenceResponse {
    repeated int64 element = 1;
}
```

the `repeated` keyword essentially says that we want to return a sequence of integer elements.

#### Endpoint 2 - `rpc StreamSequence (SequenceRequest) returns (stream SequenceElement) {}`

The second endpoint will also return a Fibonacci sequence. However, unlike the `GetSequence` endpoint, `StreamSequence` is going to stream the data points on-the-fly as we calculate them. You can image that this has all sorts of benefits including

1. Ability to send real-time updates as opposed to batching responses into a single packet
2. Much lower memory footprint - large sequences do not need to be held in memory but can be sent individually

The actual endpoint definition looks very similar to `GetSequence`. We are still using the `SequenceRequest` message to define the inputs, but rather than returning a `SequenceResponse` message, we return a `SequenceElement` message. Crucially, we also add the `stream` statement to the endpoint `returns` statement, which defines our endpoint as a streaming endpoint. The actual `SequenceElement` message contains both the sequence number as well as the position of the element in the current sequence.

### Generating Python Stubs

Once the protocol buffers have been defined, the python stubs can be generated. Remember, the python stubs are basically the interface layer between client and server, and these are auto-generated by the protocol buffer compiler I installed earlier via the `grpcio-tools` package.

The stubs and service implementations are generated using the following command

```bash
$ python -m grpc_tools.protoc -I protos --python_out=. --grpc_python_out=. protos/fibonacci.proto
```

The above should generate two files called `fibonacci_pb2.py` and `fibonacci_pb2_grpc.py`. The former contains the client stubs that we can use to generate a gRPC client. The latter contains code for the service that we can use to generate a gRPC server. I'll be covering these in separate sections below.

## Creating the server

Now that the gRPC stubs have been generated, we can define our python server. The `_pb2_grpc.py` file generated by the protocol buffer compiler contains a `FibonacciServiceServicer` class which we first need to import. The next step is to then define a new child class off of the `FibonacciServiceServicer` class that implements the `GetSequence` and `StreamSequence` endpoints that we defined in the `.proto` file (note that the name of the methods __must__ match the endpoint names defined in the protobuf service).

The code for the server implementation looks something like the following

```python
import logging
from concurrent import futures
from typing import Generator

import grpc 

from fibonacci_pb2_grpc import FibonacciServiceServicer, \
    add_FibonacciServiceServicer_to_server
from fibonacci_pb2 import SequenceRequest, SequenceResponse, \
    SequenceElement

LOGGER = logging.getLogger(__name__)

def generate_fibonacci(count: int) -> Generator[int, None, None]:
    """Generator used to construct fibonacci
    sequence"""

    a, b = 0, 1
    current_count = 0
    while True:
        yield a
        current_count += 1
        if current_count >= count:
            break
        # increment values
        a, b = b, a + b


class FibonacciService(FibonacciServiceServicer):

    def GetSequence(self, request: SequenceRequest, context) -> SequenceResponse:
        """Method used to handle retrieval of entire sequence
        via gRPC interface"""
        
        LOGGER.debug("Generating %d fibonacci sequences...", request.count)
        # generate new sequence and convert to list before
        # returning as grpc SequenceResponse
        sequence = list(generate_fibonacci(request.count))
        return SequenceResponse(elements=sequence)
    
    def StreamSequence(self, request: SequenceRequest, context) -> Generator[SequenceElement, None, None]:
        """Method used to stream Fibonacci sequence elements"""
        
        LOGGER.debug("Streaming %d fibonacci sequences...", request.count)
        sequence = generate_fibonacci(request.count)
        for i, element in enumerate(sequence):
            response = SequenceElement(element=element, count=i)
            yield response

```

Couple of things to point out

1. Function names and arguments

As mentioned above, the function names need to match the service endpoints we defined in the `.proto` file. Each of the functions takes a gRPC request object as the first argument, and a gRPC context object as the second argument. The `request` argument is an instance of the `SequenceRequest` object, which is essentially a data class with the structure that was defined in the `SequenceRequest` message in the `.proto` file. 

2. Function return values

One important thing to notice is that each of the methods defined in the class has a different return type. Simple, non-streaming endpoints return a data class instance (imported from the `pb2.py` file), which has a data structure that matches the return type specified in the `.proto` file. In this case, the service in my `.proto` file returned an instance of the `SequenceResponse` message, which contains an array of integers.

Streaming endpoints need to return a generator, and each value yielded needs to be an instance of the data class matching the return type specified in the protobuf service endpoint. In this case, I defined the return type as a `SequenceElement` message, so the generator returned by `StreamSequence` yields instances of the `SequenceElement` class.

With the endpoint implementation defined, I can generate a server instance using the following code

```python
if __name__ == '__main__':

    # generate new server
    exec = futures.ThreadPoolExecutor(max_workers=10)
    server = grpc.server(exec)
    
    # add server to gRPC server instance and add port
    add_FibonacciServiceServicer_to_server(FibonacciService(), server)
    server.add_insecure_port('[::]:50051')
    
    # start grpc server and wait for termination
    server.start()
    server.wait_for_termination()
```

Running the above will create and start a gRPC server on port `50051`.

## Creating the client

With the server up and running, it's time to generate a gRPC client to access the endpoints, which is done via the service stub and message structures defined in the python files generated by the protobuf compiler. The following code generates a gRPC client to access the `StreamSequence` endpoint.

```python
import grpc

from fibonacci_pb2_grpc import FibonacciServiceStub
from fibonacci_pb2 import SequenceRequest

# generate new channel and stub
channel = grpc.insecure_channel('localhost:50051')
stub = FibonacciServiceStub(channel)

request = SequenceRequest(count=20)
for p in stub.StreamSequence(request):
    print(p)

```

Note that calling `stub.StreamSequence` returns a generator which yields the values generated by the gRPC service. The requests themselves are formed using the `SequenceRequest` class as defined in the `.proto` file. To access the non-streaming endpoint that returns the entire sequence, use the following code

```python
# generate new channel and stub
channel = grpc.insecure_channel('localhost:50051')
stub = FibonacciServiceStub(channel)
    
print(stub.GetSequence(request))

```

Both client examples use the `FibonacciServiceStub` which contains the methods used to call the endpoints defined in the gRPC service. One of the nice things about gRPC is that the stubs used to access the service are all completed generated by the protocol buffer compiler, and only require minimum developer time to implement. This provides a clean, consistent interface that client applications can use for applications.

Thats it for today! If you want to read more about gRPC, I would suggest the official google docs. Tutorials and guides for python can be found <a href="https://grpc.io/docs/languages/python/">here</a>, while the docs for the protobuf language guide can be found <a href="https://developers.google.com/protocol-buffers/docs/proto3">here</a>.