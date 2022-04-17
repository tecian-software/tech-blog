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
        return SequenceResponse(element=sequence)
    
    def StreamSequence(self, request: SequenceRequest, context) -> Generator[SequenceElement, None, None]:
        """Method used to stream Fibonacci sequence elements"""
        
        LOGGER.debug("Streaming %d fibonacci sequences...", request.count)
        sequence = generate_fibonacci(request.count)
        for i, element in enumerate(sequence):
            response = SequenceElement(element=element, count=i)
            yield response
            

if __name__ == '__main__':
    
    logging.basicConfig(level=logging.DEBUG)
    
    # generate new server
    exec = futures.ThreadPoolExecutor(max_workers=10)
    server = grpc.server(exec)
    
    # add server to gRPC server instance and add port
    add_FibonacciServiceServicer_to_server(FibonacciService(), server)
    server.add_insecure_port('[::]:5001')
    
    # start grpc server and wait for termination
    server.start()
    server.wait_for_termination()