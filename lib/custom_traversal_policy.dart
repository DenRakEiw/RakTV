import 'dart:math';

import 'package:flutter/material.dart';

/// This traversal policy manages up, down, left, and right directions
/// predictably across rows and grids, with tolerance for 1.1x scaled focused cards.
class RowByRowTraversalPolicy extends FocusTraversalPolicy with DirectionalFocusTraversalPolicyMixin {
  @override
  Iterable<FocusNode> sortDescendants(Iterable<FocusNode> descendants, FocusNode currentNode) => descendants;

  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    List<FocusNode>? nodes = currentNode.nearestScope?.traversalDescendants.toList();
    if (nodes == null) {
      return super.inDirection(currentNode, direction);
    }

    NodeSearcher searcher = NodeSearcher(direction);
    List<CandidateNode> candidates = searcher.findCandidates(nodes, currentNode);
    if (candidates.isEmpty) {
      return super.inDirection(currentNode, direction);
    }
    FocusNode nextNode = searcher.findBestFocusNode(candidates, currentNode);
    nextNode.requestFocus();
    return true;
  }
}

class NodeSearcher {
  final TraversalDirection directionToSearch;

  NodeSearcher(this.directionToSearch);

  List<CandidateNode> findCandidates(List<FocusNode> nodes, FocusNode from) {
    List<FocusNode> copy = List.from(nodes, growable: true);
    copy.remove(from);

    switch (directionToSearch) {
      case TraversalDirection.up:
        copy.removeWhere((element) => !element.isAbove(from));
        break;
      case TraversalDirection.down:
        copy.removeWhere((element) => !element.isBelow(from));
        break;
      case TraversalDirection.right:
        copy.removeWhere((element) => !element.isRightTo(from) || !element.isOnTheSameRow(from));
        break;
      case TraversalDirection.left:
        copy.removeWhere((element) => !element.isLeftTo(from) || !element.isOnTheSameRow(from));
        break;
    }
    return toCandidateNodes(copy);
  }

  FocusNode findBestFocusNode(List<CandidateNode> nodes, FocusNode from) {
    List<FocusNode> candidates = toFocusNodes(nodes);

    return candidates.reduce((bestNode, challenger) {
      if (directionToSearch == TraversalDirection.down) {
        if (!challenger.isOnTheSameRow(bestNode)) {
          return challenger.rect.center.dy < bestNode.rect.center.dy ? challenger : bestNode;
        }
        return challenger.horizontalDistance(from) < bestNode.horizontalDistance(from) ? challenger : bestNode;
      } else if (directionToSearch == TraversalDirection.up) {
        if (!challenger.isOnTheSameRow(bestNode)) {
          return challenger.rect.center.dy > bestNode.rect.center.dy ? challenger : bestNode;
        }
        return challenger.horizontalDistance(from) < bestNode.horizontalDistance(from) ? challenger : bestNode;
      } else if (directionToSearch == TraversalDirection.left) {
        return challenger.rect.center.dx > bestNode.rect.center.dx ? challenger : bestNode;
      } else if (directionToSearch == TraversalDirection.right) {
        return challenger.rect.center.dx < bestNode.rect.center.dx ? challenger : bestNode;
      }
      return bestNode;
    });
  }
}

class CandidateNode {
  final FocusNode node;

  CandidateNode(this.node);
}

List<CandidateNode> toCandidateNodes(List<FocusNode> nodes) => nodes.map((e) => CandidateNode(e)).toList();

List<FocusNode> toFocusNodes(List<CandidateNode> nodes) => nodes.map((e) => e.node).toList();

const double _rowTolerance = 28.0;
const double _colTolerance = 8.0;

extension Geometry on FocusNode {
  bool isOnTheSameRow(FocusNode other) {
    return (rect.center.dy - other.rect.center.dy).abs() <= _rowTolerance;
  }

  bool isBelow(FocusNode other) {
    return rect.center.dy - other.rect.center.dy > _rowTolerance;
  }

  bool isAbove(FocusNode other) {
    return other.rect.center.dy - rect.center.dy > _rowTolerance;
  }

  bool isRightTo(FocusNode other) {
    return rect.center.dx - other.rect.center.dx > _colTolerance;
  }

  bool isLeftTo(FocusNode other) {
    return other.rect.center.dx - rect.center.dx > _colTolerance;
  }

  double horizontalDistance(FocusNode other) {
    return (rect.center.dx - other.rect.center.dx).abs();
  }

  double distance(FocusNode other) {
    return sqrt(pow(rect.center.dx - other.rect.center.dx, 2) + pow(rect.center.dy - other.rect.center.dy, 2));
  }
}
