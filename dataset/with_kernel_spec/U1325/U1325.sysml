package HighThroughputMessageSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import Definitions::*;

	package Definitions {
		item def RawMessage {
			attribute id : String;
			attribute payload : String;
			attribute destination : String;
			attribute priority : Integer := 0;
			attribute timestamp : TimeValue;
			attribute isValid : Boolean := false;
		}

		item def ProcessedMessage {
			attribute id : String;
			attribute payload : String;
			attribute destination : String;
			attribute priority : Integer;
			attribute timestamp : TimeValue;
			attribute processedAt : TimeValue;
			attribute enrichmentData : String;
		}

		attribute def QueueOverload;
		attribute def ResetSignal;
		attribute def ShutdownSignal;

		port def RawMessagePort {
			out item msg : RawMessage;
		}

		port def ProcessedMessagePort {
			out item msg : ProcessedMessage;
		}

		action def ValidateMessage {
			in rawMsg : RawMessage;
			out validMsg : RawMessage;
			out invalidMsg : RawMessage;
		}

		action def ProcessMessage {
			in rawMsg : RawMessage;
			out procMsg : ProcessedMessage;
		}

		action def RouteMessage {
			in procMsg : ProcessedMessage;
			out routedMsg : ProcessedMessage;
		}

		action def BufferMessage {
			in msg : RawMessage;
		}

		action def ArchiveMessage {
			in msg : RawMessage;
		}

		part def NetworkInterface {
			port extInPort : ~RawMessagePort;
			port toValidatorPort : RawMessagePort;
			port fromRouterPort : ~ProcessedMessagePort;
			port extOutPort : ProcessedMessagePort;
			attribute messageCount : Integer := 0;
		}

		part def MessageValidator {
			port inPort : ~RawMessagePort;
			port validOutPort : RawMessagePort;
			port invalidOutPort : RawMessagePort;
			attribute validatedCount : Integer := 0;
			attribute rejectedCount : Integer := 0;
			perform action validate : ValidateMessage;
			exhibit state behavior {
				entry; then waiting;
				state waiting;
				transition
					first waiting
					accept msg : RawMessage via inPort
					do validate
					then waiting;
			}
		}

		part def MessageProcessor {
			port inPort : ~RawMessagePort;
			port outPort : ProcessedMessagePort;
			attribute queueDepth : Integer := 0;
			attribute maxQueueDepth : Integer := 1000;
			perform action process : ProcessMessage;
			exhibit state states {
				entry; then idle;
				state idle;
				transition
					first idle
					accept msg : RawMessage via inPort
					if queueDepth < maxQueueDepth
					do assign queueDepth := queueDepth + 1
					then processing;
				transition
					first idle
					accept QueueOverload
					then error;
				state processing {
					do process;
					exit assign queueDepth := queueDepth - 1;
				}
				then idle;
				transition
					first processing
					accept QueueOverload
					if queueDepth >= maxQueueDepth
					then error;
				state error;
				transition
					first error
					accept ResetSignal
					do assign queueDepth := 0
					then idle;
			}
		}

		part def MessageRouter {
			port inPort : ~ProcessedMessagePort;
			port outPort : ProcessedMessagePort;
			attribute routedCount : Integer := 0;
			perform action route : RouteMessage;
			exhibit state behavior {
				entry; then listening;
				state listening;
				transition
					first listening
					accept msg : ProcessedMessage via inPort
					do route
					then listening;
			}
		}

		part def MessageStorage {
			port bufferInPort : ~RawMessagePort;
			port bufferOutPort : RawMessagePort;
			port archiveInPort : ~RawMessagePort;
			attribute capacity : Integer := 10000;
			attribute storedCount : Integer := 0;
			item storedMessages[*] : RawMessage;
			perform action buffer : BufferMessage;
			perform action archive : ArchiveMessage;
			exhibit state behavior {
				entry; then ready;
				state ready;
				transition
					first ready
					accept msg : RawMessage via archiveInPort
					do archive
					then ready;
				transition
					first ready
					accept msg : RawMessage via bufferInPort
					do buffer
					then ready;
			}
		}
	}

	package Usages {
		private import Definitions::*;

		part messageSystem {
			exhibit state systemStates {
				entry; then operational;
				state operational;
				accept ShutdownSignal
					then terminated;
				state terminated;
			}

			part networkInterface : NetworkInterface {
				flow of msg : RawMessage
					from extInPort.msg to toValidatorPort.msg;
				flow of msg : ProcessedMessage
					from fromRouterPort.msg to extOutPort.msg;
			}

			part validator : MessageValidator {
				perform action validate : ValidateMessage {
					in rawMsg = inPort.msg;
					out validMsg = validOutPort.msg;
					out invalidMsg = invalidOutPort.msg;
				}
			}

			part processors[3] : MessageProcessor {
				perform action process : ProcessMessage {
					in rawMsg = inPort.msg;
					out procMsg = outPort.msg;
				}
			}

			part router : MessageRouter {
				perform action route : RouteMessage {
					in procMsg = inPort.msg;
					out routedMsg = outPort.msg;
				}
			}

			part storage : MessageStorage {
				perform action buffer : BufferMessage {
					in msg = bufferInPort.msg;
				}
				perform action archive : ArchiveMessage {
					in msg = archiveInPort.msg;
				}
			}

			flow of msg : RawMessage
				from networkInterface.toValidatorPort.msg to validator.inPort.msg;
			flow of msg : RawMessage
				from validator.validOutPort.msg to processors.inPort.msg;
			flow of msg : RawMessage
				from validator.invalidOutPort.msg to storage.archiveInPort.msg;
			flow of msg : ProcessedMessage
				from processors.outPort.msg to router.inPort.msg;
			flow of msg : ProcessedMessage
				from router.outPort.msg to networkInterface.fromRouterPort.msg;
			flow of msg : RawMessage
				from storage.bufferOutPort.msg to processors.inPort.msg;
		}
	}

	package Requirements {
		private import ScalarValues::*;
		private import ISQ::*;

		requirement def PerformanceSpec {
			attribute minThroughput : Integer;
			attribute maxEndToEndLatency : Real;
		}

		requirement def ReliabilitySpec {
			attribute faultTolerant : Boolean;
			attribute minParallelProcessors : Integer;
		}

		requirement def ValidationSpec {
			attribute rejectInvalidMessages : Boolean;
		}

		requirement throughputRequirement : PerformanceSpec {
			doc /* Minimum processing rate of 6000 messages per second. */
			attribute :>> minThroughput = 6000;
		}

		requirement latencyRequirement : PerformanceSpec {
			doc /* End-to-end delay under 50 milliseconds. */
			attribute :>> maxEndToEndLatency = 50.0;
		}

		requirement reliabilityRequirement : ReliabilitySpec {
			attribute :>> faultTolerant = true;
			attribute :>> minParallelProcessors = 3;
		}

		requirement validationRequirement : ValidationSpec {
			attribute :>> rejectInvalidMessages = true;
		}

		part systemInstance :> Usages::messageSystem {
			satisfy throughputRequirement;
			satisfy latencyRequirement;
			satisfy reliabilityRequirement;
			satisfy validationRequirement;
		}
	}
}
