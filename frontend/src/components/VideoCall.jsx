import React, { useState, useRef, useEffect } from "react";
import { useAuthStore } from "../store/useAuthStore";
import { Video, PhoneOff } from "lucide-react";
import { toast } from "react-toastify";

const VideoCallButton = ({ roomId, currentUserId, targetUserId }) => {
  const { socket } = useAuthStore();
  const localVideoRef = useRef(null);
  const remoteVideoRef = useRef(null);
  const peerConnectionRef = useRef(null);
  const localStreamRef = useRef(null);
  const [inCall, setInCall] = useState(false);

  useEffect(() => {
    if (!socket) return;

    socket.emit("join-room", { roomId, userId: currentUserId });

    socket.on("user-joined", async ({ userId }) => {
      await createOffer(userId);
    });

    socket.on("offer", async ({ offer, from }) => {
      await handleOffer(offer, from);
    });

    socket.on("answer", async ({ answer }) => {
      await peerConnectionRef.current.setRemoteDescription(new RTCSessionDescription(answer));
    });

    socket.on("ice-candidate", async ({ candidate }) => {
      try {
        await peerConnectionRef.current.addIceCandidate(new RTCIceCandidate(candidate));
      } catch (err) {
        console.error("Error adding ice candidate", err);
      }
    });

    return () => {
      socket.off("user-joined");
      socket.off("offer");
      socket.off("answer");
      socket.off("ice-candidate");
    };
  }, [socket]);

  const startCall = async () => {
    if (!socket || inCall) return;

    setInCall(true);
    const localStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
    localStreamRef.current = localStream;
    localVideoRef.current.srcObject = localStream;

    peerConnectionRef.current = createPeerConnection(targetUserId);

    localStream.getTracks().forEach((track) => {
      peerConnectionRef.current.addTrack(track, localStream);
    });
  };

  const endCall = () => {
    if (peerConnectionRef.current) {
      peerConnectionRef.current.close();
      peerConnectionRef.current = null;
    }

    if (localStreamRef.current) {
      localStreamRef.current.getTracks().forEach((track) => track.stop());
      localStreamRef.current = null;
    }

    if (localVideoRef.current) localVideoRef.current.srcObject = null;
    if (remoteVideoRef.current) remoteVideoRef.current.srcObject = null;

    setInCall(false);
    toast.info("Call Ended", { position: "top-right" });
  };

  const createPeerConnection = (targetId) => {
    const pc = new RTCPeerConnection({
      iceServers: [{ urls: "stun:stun.l.google.com:19302" }],
    });

    pc.onicecandidate = (event) => {
      if (event.candidate && socket) {
        socket.emit("ice-candidate", { candidate: event.candidate, to: targetId });
      }
    };

    pc.ontrack = (event) => {
      remoteVideoRef.current.srcObject = event.streams[0];
    };

    return pc;
  };

  const createOffer = async (targetId) => {
    peerConnectionRef.current = createPeerConnection(targetId);
    const localStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
    localStreamRef.current = localStream;
    localVideoRef.current.srcObject = localStream;

    localStream.getTracks().forEach((track) => {
      peerConnectionRef.current.addTrack(track, localStream);
    });

    const offer = await peerConnectionRef.current.createOffer();
    await peerConnectionRef.current.setLocalDescription(offer);

    socket.emit("offer", { offer, to: targetId });
  };

  const handleOffer = async (offer, from) => {
    peerConnectionRef.current = createPeerConnection(from);
    const localStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
    localStreamRef.current = localStream;
    localVideoRef.current.srcObject = localStream;

    localStream.getTracks().forEach((track) => {
      peerConnectionRef.current.addTrack(track, localStream);
    });

    await peerConnectionRef.current.setRemoteDescription(new RTCSessionDescription(offer));

    const answer = await peerConnectionRef.current.createAnswer();
    await peerConnectionRef.current.setLocalDescription(answer);

    socket.emit("answer", { answer, to: from });
  };

  return (
    <div>
      {!inCall ? (
        <button
          onClick={startCall}
          className="px-3 py-1.5 bg-teal-500 text-white rounded-full hover:bg-teal-600 transition duration-200 shadow-md"
          title="Start Video Call"
        >
          <Video size={20} />
        </button>
      ) : (
        <div className="flex flex-col gap-4 mt-4">
          <div className="video-container flex gap-4">
            <video ref={localVideoRef} autoPlay playsInline muted width="300" />
            <video ref={remoteVideoRef} autoPlay playsInline width="300" />
          </div>
          <button
            onClick={endCall}
            className="px-3 py-1.5 bg-red-600 text-white rounded-full hover:bg-red-700 transition duration-200 self-start shadow-md"
            title="End Call"
          >
            <PhoneOff size={20} />
          </button>
        </div>
      )}
    </div>
  );
};

export default VideoCallButton;
