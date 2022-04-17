
import grpc

from fibonacci_pb2_grpc import FibonacciServiceStub
from fibonacci_pb2 import SequenceRequest

# generate new channel and stub
channel = grpc.insecure_channel('localhost:50051')
stub = FibonacciServiceStub(channel)

request = SequenceRequest(count=20)
for p in stub.StreamSequence(request):
    print(p)
    
print(stub.GetSequence(request))