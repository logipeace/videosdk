import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:videosdk/videosdk.dart';

import 'participant_tile.dart';

class ParticipantGridView extends StatefulWidget {
  final Room meeting;
  const ParticipantGridView({
    Key? key,
    required this.meeting,
  }) : super(key: key);

  @override
  State<ParticipantGridView> createState() => _ParticipantGridViewState();
}

class _ParticipantGridViewState extends State<ParticipantGridView> {
  String? activeSpeakerId;
  Participant? localParticipant;
  Map<String, Participant> participants = {};
  Map<String, ParticipantPinState> pinnedParticipants = {};

  @override
  void initState() {
    // Initialize participants
    localParticipant = widget.meeting.localParticipant;
    participants = widget.meeting.participants;
    pinnedParticipants = widget.meeting.pinnedParticipants;
    if(widget.meeting.characters!= null){
      for(Character character in widget.meeting.characters!.values){
        participants[character.id] = character;
      }
    }

    // Setting meeting event listeners
    setMeetingListeners(widget.meeting);
    super.initState();
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      children: [
        ParticipantTile(
          pinState: pinnedParticipants[localParticipant!.id] ??
              localParticipant!.pinState,
          participant: localParticipant!,
          isLocalParticipant: true,
        ),
        ...participants.values
            .map((participant) => ParticipantTile(
                  participant: participant,
                  pinState: pinnedParticipants[participant.id] ??
                      participant.pinState,
                ))
            .toList()
      ],
    );
  }

  void setMeetingListeners(Room _meeting) {
    // Called when participant joined meeting
    _meeting.on(
      Events.participantJoined,
      (Participant participant) {
        final newParticipants = participants;
        newParticipants[participant.id] = participant;
        setState(() {
          participants = newParticipants;
        });
      },
    );

    // Called when participant left meeting
    _meeting.on(
      Events.participantLeft,
      (participantId) {
        final newParticipants = participants;

        newParticipants.remove(participantId);
        setState(() {
          participants = newParticipants;
        });
      },
    );

    _meeting.on(Events.characterJoined, (Character character ) {
      final newParticipants = participants;
        newParticipants[character.id] = character;
        setState(() {
          participants = newParticipants;
        });
    });

    _meeting.on(Events.characterLeft, (Character character ) {
      final newParticipants = participants;

        newParticipants.remove(character.id);
        setState(() {
          participants = newParticipants;
        });
    });

    // Called when speaker is changed
    _meeting.on(Events.speakerChanged, (_activeSpeakerId) {
      setState(() {
        activeSpeakerId = _activeSpeakerId;
      });

      log("meeting speaker-changed => $_activeSpeakerId");
    });

    _meeting.on(Events.pinStateChanged, (data) {
      setState(() {
        pinnedParticipants = _meeting.pinnedParticipants;
      });
    });

    _meeting.on(Events.participantModeChanged, (data) {
      setState(() {
        participants = _meeting.participants;
      });
    });
  }
}
