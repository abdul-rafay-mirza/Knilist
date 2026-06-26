_VIEWER_QUERY = """
query {
  Viewer {
    id
    name
    avatar { large }
    mediaListOptions {
      scoreFormat
    }
  }
}
"""

_ANIME_LIST_QUERY = """
query ($userId: Int) {
  MediaListCollection(userId: $userId, type: ANIME) {
    lists {
      entries {
        id
        status
        score
        progress
        repeat
        notes
        priority
        hiddenFromStatusLists
        private
        startedAt  { year month day }
        completedAt { year month day }
        updatedAt
        media {
          id
          title { userPreferred romaji }
          format
          episodes
          coverImage { large }
          nextAiringEpisode {
            episode
            timeUntilAiring
          }
        }
      }
    }
  }
}
"""

_MANGA_LIST_QUERY = """
query ($userId: Int) {
  MediaListCollection(userId: $userId, type: MANGA) {
    lists {
      entries {
        id
        status
        score
        progress
        progressVolumes
        repeat
        notes
        priority
        hiddenFromStatusLists
        private
        startedAt  { year month day }
        completedAt { year month day }
        updatedAt
        media {
          id
          title { userPreferred romaji }
          format
          chapters
          volumes
          coverImage { large }
        }
      }
    }
  }
}
"""

_SAVE_ENTRY_MUTATION = """
mutation (
  $mediaId:              Int,
  $status:               MediaListStatus,
  $score:                Float,
  $progress:             Int,
  $repeat:               Int,
  $notes:                String,
  $priority:             Int,
  $hiddenFromStatusLists: Boolean,
  $private:              Boolean,
  $startedAt:            FuzzyDateInput,
  $completedAt:          FuzzyDateInput
) {
  SaveMediaListEntry(
    mediaId:              $mediaId,
    status:               $status,
    score:                $score,
    progress:             $progress,
    repeat:               $repeat,
    notes:                $notes,
    priority:             $priority,
    hiddenFromStatusLists: $hiddenFromStatusLists,
    private:              $private,
    startedAt:            $startedAt,
    completedAt:          $completedAt
  ) {
    id
    progress
    status
    score
  }
}
"""

_SAVE_MANGA_ENTRY_MUTATION = """
mutation (
  $mediaId:              Int,
  $status:               MediaListStatus,
  $score:                Float,
  $progress:             Int,
  $progressVolumes:      Int,
  $repeat:               Int,
  $notes:                String,
  $priority:             Int,
  $hiddenFromStatusLists: Boolean,
  $private:              Boolean,
  $startedAt:            FuzzyDateInput,
  $completedAt:          FuzzyDateInput
) {
  SaveMediaListEntry(
    mediaId:              $mediaId,
    status:               $status,
    score:                $score,
    progress:             $progress,
    progressVolumes:      $progressVolumes,
    repeat:               $repeat,
    notes:                $notes,
    priority:             $priority,
    hiddenFromStatusLists: $hiddenFromStatusLists,
    private:              $private,
    startedAt:            $startedAt,
    completedAt:          $completedAt
  ) {
    id
    progress
    progressVolumes
    status
    score
  }
}
"""

_DELETE_ENTRY_MUTATION = """
mutation ($id: Int) {
  DeleteMediaListEntry(id: $id) {
    deleted
  }
}
"""

_TOGGLE_FAVOURITE_MUTATION = """
mutation ($animeId: Int) {
  ToggleFavourite(animeId: $animeId) {
    anime {
      nodes { id }
    }
  }
}
"""

_ANIME_PAGE_QUERY = """
query ($id: Int) {
  Media(id: $id, type: ANIME) {
    id
    title {
      romaji
      english
      native
    }
    nextAiringEpisode {
      airingAt
      timeUntilAiring
      episode
    }
    format
    episodes
    duration
    status
    startDate {
      day
      month
      year
    }
    endDate {
      day
      month
      year
    }
    averageScore
    meanScore
    popularity
    favourites
    isFavourite
    studios {
      nodes {
        name
        isAnimationStudio
      }
    }
    source
    hashtag
    genres
    synonyms
    tags {
      name
      rank
      isMediaSpoiler
    }
    externalLinks {
      site
      url
    }
    bannerImage
    coverImage {
      large
    }
    description
    relations {
      edges {
        relationType(version: 2)
        node {
          id
          type
          format
          title {
            romaji
            english
          }
          coverImage {
            large
          }
          status
        }
      }
    }
    characters(sort: [FAVOURITES_DESC, ROLE], perPage: 24) {
      edges {
        role
        node {
          id
          name {
            full
            native
          }
          image {
            large
          }
        }
      }
    }
    staff(sort: [FAVOURITES_DESC, ROLE], perPage: 6) {
      edges {
        role
        node {
          id
          name {
            full
            native
          }
          image {
            large
          }
        }
      }
    }
    recommendations(sort: [RATING_DESC], perPage: 30) {
      nodes {
        mediaRecommendation {
          id
          title {
            english
            native
            romaji
          }
          coverImage {
            large
          }
        }
      }
    }
  }
}
"""

_CHARACTER_PAGE_QUERY = """
query ($id: Int) {
  Character (id: $id) {
    name {
      first
      middle
      last
      full
      native
      alternative
      alternativeSpoiler
      userPreferred
    }
    image {
      large
    }
    description
    age
    bloodType
    isFavourite
    isFavouriteBlocked
    gender
    dateOfBirth {
      day
      month
      year
    }
    siteUrl
    media {
      nodes {
        id
        type
        title {
          english
          native
          romaji
        }
        coverImage {
          extraLarge
        }
      }
    }
  }
}
"""

_TOGGLE_CHARACTER_FAVOURITE_MUTATION = """
mutation ($characterId: Int) {
  ToggleFavourite(characterId: $characterId) {
    characters {
      nodes { id }
    }
  }
}
"""