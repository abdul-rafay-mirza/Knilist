# This query is responsible for fetching the currently logged-in user’s (the viewer's) private settings, UI preferences, and system state.
_VIEWER_QUERY = """
query {
  Viewer {
    id
    name
    about

    avatar {
      large
    }

    bannerImage
    unreadNotificationCount
    donatorTier
    donatorBadge
    moderatorRoles

    options {
      titleLanguage
      staffNameLanguage
      restrictMessagesToFollowing
      airingNotifications
      displayAdultContent
      profileColor

      notificationOptions {
        type
        enabled
      }

      disabledListActivity {
        type
        disabled
      }
    }

    mediaListOptions {
      scoreFormat
      rowOrder

      animeList {
        customLists
        sectionOrder
        splitCompletedSectionByFormat
        advancedScoring
        advancedScoringEnabled
      }

      mangaList {
        customLists
        sectionOrder
        splitCompletedSectionByFormat
        advancedScoring
        advancedScoringEnabled
      }
    }
  }
}
"""

# The query for any anilist user
_USER_QUERY = """
query (
  $id:          Int!,
  $name:        String,
  $animePage:   Int = 1,
  $mangaPage:   Int = 1,
  $charPage:    Int = 1,
  $staffPage:   Int = 1,
  $studioPage:  Int = 1,
  $perPage:     Int = 25
) {
  User(id: $id, name: $name) {
    id
    name
    previousNames { name updatedAt }
    avatar { large }
    bannerImage
    about
    isFollowing
    isFollower
    donatorTier
    donatorBadge
    createdAt
    moderatorRoles
    isBlocked
    bans

    options { profileColor restrictMessagesToFollowing }
    mediaListOptions { scoreFormat }

    statistics {
      anime {
        count meanScore standardDeviation minutesWatched episodesWatched
        genrePreview: genres(limit: 10, sort: COUNT_DESC) { genre count }
      }
      manga {
        count meanScore standardDeviation chaptersRead volumesRead
        genrePreview: genres(limit: 10, sort: COUNT_DESC) { genre count }
      }
    }

    stats { activityHistory { date amount level } }

    favourites {
      anime(page: $animePage, perPage: $perPage) {
        pageInfo { hasNextPage }
        edges {
          favouriteOrder
          node {
            id type status(version: 2) format isAdult bannerImage
            title { userPreferred }
            coverImage { large }
          }
        }
      }
      manga(page: $mangaPage, perPage: $perPage) {
        pageInfo { hasNextPage }
        edges {
          favouriteOrder
          node {
            id type status(version: 2) format isAdult bannerImage
            title { userPreferred }
            coverImage { large }
          }
        }
      }
      characters(page: $charPage, perPage: $perPage) {
        pageInfo { hasNextPage }
        edges { favouriteOrder node { id name { userPreferred } image { large } } }
      }
      staff(page: $staffPage, perPage: $perPage) {
        pageInfo { hasNextPage }
        edges { favouriteOrder node { id name { userPreferred } image { large } } }
      }
      studios(page: $studioPage, perPage: $perPage) {
        pageInfo { hasNextPage }
        edges { favouriteOrder node { id name } }
      }
    }
  }

  followingPage: Page(perPage: 1) {
    pageInfo { total }
    following(userId: $id) { id }
  }

  followersPage: Page(perPage: 1) {
    pageInfo { total }
    followers(userId: $id) { id }
  }
}
"""

_PROFILE_PAGE_QUERY = """
query (
  $userId:     Int!,
  $animePage:  Int = 1,
  $mangaPage:  Int = 1,
  $charPage:   Int = 1,
  $staffPage:  Int = 1,
  $studioPage: Int = 1
) {
  Viewer {
    id
    name
    about
    avatar { large }
    bannerImage
    unreadNotificationCount
    donatorTier
    donatorBadge
    moderatorRoles

    options {
      titleLanguage
      displayAdultContent
      profileColor
    }

    mediaListOptions {
      scoreFormat
    }

    statistics {
      anime {
        count
        meanScore
        minutesWatched
        episodesWatched

        statuses { status count }

        genresLoved: genres(limit: 3, sort: COUNT_DESC) { genre count }
        genresHated: genres(limit: 10, sort: MEAN_SCORE) { genre count meanScore }

        tagsLoved: tags(limit: 15, sort: COUNT_DESC) {
          count
          tag { name category }
        }

        yearsLoved: releaseYears(limit: 15, sort: MEAN_SCORE_DESC) {
          releaseYear
          count
          meanScore
        }

        startYears { startYear count }
      }

      manga {
        count
        meanScore
        chaptersRead
        volumesRead
      }
    }

    favourites {
      anime(page: $animePage, perPage: 25) {
        pageInfo { hasNextPage }
        edges {
          favouriteOrder
          node { id title { userPreferred } coverImage { large } }
        }
      }
      manga(page: $mangaPage, perPage: 25) {
        pageInfo { hasNextPage }
        edges {
          favouriteOrder
          node { id title { userPreferred } coverImage { large } }
        }
      }
      characters(page: $charPage, perPage: 25) {
        pageInfo { hasNextPage }
        edges {
          favouriteOrder
          node { id name { userPreferred } image { large } }
        }
      }
      staff(page: $staffPage, perPage: 25) {
        pageInfo { hasNextPage }
        edges {
          favouriteOrder
          node { id name { userPreferred } image { large } }
        }
      }
      studios(page: $studioPage, perPage: 25) {
        pageInfo { hasNextPage }
        edges {
          favouriteOrder
          node { id name }
        }
      }
    }
  }

  followingPage: Page(perPage: 1) {
    pageInfo { total }
    following(userId: $userId) { id }
  }

  followersPage: Page(perPage: 1) {
    pageInfo { total }
    followers(userId: $userId) { id }
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
          title { userPreferred romaji english }
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
          title { userPreferred romaji english }
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

_SAVE_ANIME_ENTRY_MUTATION = """
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

_DELETE_ANIME_ENTRY_MUTATION = """
mutation ($id: Int) {
  DeleteMediaListEntry(id: $id) {
    deleted
  }
}
"""

_DELETE_MANGA_ENTRY_MUTATION = """
mutation ($id: Int) {
  DeleteMediaListEntry(id: $id) {
    deleted
  }
}
"""

_TOGGLE_ANIME_FAVOURITE_MUTATION = """
mutation ($animeId: Int) {
  ToggleFavourite(animeId: $animeId) {
    anime {
      nodes { id }
    }
  }
}
"""

_TOGGLE_MANGA_FAVOURITE_MUTATION = """
mutation ($mangaId: Int) {
  ToggleFavourite(mangaId: $mangaId) {
    manga {
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
      userPreferred
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
    season
    seasonYear
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
        id
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
    characters(sort: [RELEVANCE], perPage: 25) {
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
    staff(sort: [RELEVANCE], perPage: 3) {
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
      full
      native
      alternative
      alternativeSpoiler
      userPreferred
    }
    image { large }
    description
    age
    bloodType
    isFavourite
    isFavouriteBlocked
    gender
    dateOfBirth { day month year }
    siteUrl
    media {
      edges {
        node {
          id
          type
          title { english native romaji }
          coverImage { extraLarge }
        }
        voiceActors(sort: [RELEVANCE]) {
          id
          name { full native userPreferred }
          image { large }
          languageV2
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

_STAFF_PAGE_QUERY = """
query ($id: Int) {
  Staff(id: $id) {
    name { full native alternative userPreferred }
    languageV2
    image { large }
    description
    primaryOccupations
    gender
    dateOfBirth { day month year }
    dateOfDeath { day month year }
    age
    yearsActive
    homeTown
    bloodType
    isFavourite
    isFavouriteBlocked
    siteUrl

    staffMedia(sort: [POPULARITY_DESC], perPage: 25, page: 1) {
      pageInfo { hasNextPage }
      edges {
        staffRole
        node {
          id
          type
          title { userPreferred english romaji }
          coverImage { large }
        }
      }
    }

    characters(sort: [FAVOURITES_DESC], perPage: 25, page: 1) {
      pageInfo { hasNextPage }
      edges {
        node {
          id
          name { userPreferred native }
          image { large }
        }
        media {
          id
          title { userPreferred english romaji }
          coverImage { large }
        }
      }
    }
  }
}
"""

_STAFF_PAGE_NEXT_QUERY = """
query ($id: Int, $mediaPage: Int, $charPage: Int) {
  Staff(id: $id) {
    staffMedia(sort: [POPULARITY_DESC], perPage: 25, page: $mediaPage) {
      pageInfo { hasNextPage }
      edges {
        staffRole
        node {
          id
          type
          title { userPreferred english romaji }
          coverImage { large }
        }
      }
    }
    characters(sort: [FAVOURITES_DESC], perPage: 25, page: $charPage) {
      pageInfo { hasNextPage }
      edges {
        node {
          id
          name { userPreferred native }
          image { large }
        }
        media {
          id
          title { userPreferred english romaji }
          coverImage { large }
        }
      }
    }
  }
}
"""

_TOGGLE_STAFF_FAVOURITE_MUTATION = """
mutation ($staffId: Int) {
  ToggleFavourite(staffId: $staffId) {
    staff {
      nodes { id }
    }
  }
}
"""

_ANIME_FAVOURITE_QUERY = """
query ($id: Int) {
  Media(id: $id, type: ANIME) {
    isFavourite
  }
}
"""

_MANGA_FAVOURITE_QUERY = """
query ($id: Int) {
  Media(id: $id, type: MANGA) {
    isFavourite
  }
}
"""

_CHARACTER_FAVOURITE_QUERY = """
query ($id: Int) {
  Character(id: $id) {
    isFavourite
  }
}
"""

_STAFF_FAVOURITE_QUERY = """
query ($id: Int) {
  Staff(id: $id) {
    isFavourite
  }
}
"""

# Variables for _STUDIO_PAGE_QUERY
# {
#   "id": 2,
#   "page": 1,
#   "perPage": 25,
#   "sort": ["START_DATE_DESC"]
# }
_STUDIO_PAGE_QUERY = """
query (
  $id: Int,
  $page: Int = 1,
  $perPage: Int = 25,
  $sort: [MediaSort] = START_DATE_DESC
) {
  Studio(id: $id) {
    name
    isFavourite
    media(
      page: $page
      perPage: $perPage
      sort: $sort
    ) {
      pageInfo {
        hasNextPage
      }
      edges {
        node {
          id
          title {
            userPreferred
          }
          startDate {
            year
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

_TOGGLE_STUDIO_FAVOURITE_MUTATION = """
mutation ($studioId: Int) {
  ToggleFavourite(studioId: $studioId) {
    studios {
      nodes { id }
    }
  }
}
"""

_STUDIO_FAVOURITE_QUERY = """
query ($id: Int) {
  Studio(id: $id) {
    isFavourite
  }
}
"""

_ALL_CHARACTERS_QUERY = """
query ($id: Int, $page: Int = 1) {
  Media(id: $id) {
    characters(page: $page, perPage: 25, sort: [ROLE, RELEVANCE]) {
      pageInfo {
        currentPage
        lastPage
        hasNextPage
      }
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
  }
}
"""

_ALL_STAFF_QUERY = """
query ($id: Int, $page: Int = 1) {
  Media(id: $id) {
    staff(page: $page, perPage: 25, sort: [RELEVANCE]) {
      pageInfo {
        currentPage
        lastPage
        hasNextPage
      }
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
  }
}
"""

_MANGA_PAGE_QUERY = """
query ($id: Int) {
  Media(id: $id, type: MANGA) {
    id
    title {
      romaji
      english
      native
      userPreferred
    }
    format
    chapters
    volumes
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
    source
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
    characters(sort: [RELEVANCE], perPage: 25) {
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
    staff(sort: [RELEVANCE], perPage: 3) {
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

_FOLLOWING_LIST_QUERY = """
query ($userId: Int!, $page: Int = 1) {
  Page(page: $page, perPage: 25) {
    pageInfo {
      hasNextPage
    }
    following(userId: $userId, sort: [USERNAME]) {
      id
      name
      avatar {
        large
      }
      bannerImage
      isFollowing
      isFollower
      createdAt
      updatedAt
    }
  }
}
"""

_FOLLOWERS_LIST_QUERY = """
query ($userId: Int!, $page: Int = 1) {
  Page(page: $page, perPage: 25) {
    pageInfo {
      hasNextPage
    }
    followers(userId: $userId, sort: [USERNAME]) {
      id
      name
      avatar {
        large
      }
      bannerImage
      isFollowing
      isFollower
      createdAt
      updatedAt
    }
  }
}
"""

_TOGGLE_FOLLOW_MUTATION = """
mutation ($userId: Int) {
  ToggleFollow(userId: $userId) {
    id
    isFollowing
    isFollower
  }
}
"""

# Search (HomePage's dropdown -> SearchPage)
# One query per Page connection that supports a `search: String` argument.
# `media` is shared by both the Anime and Manga tabs — only `$type` differs.
# `sort: SEARCH_MATCH` asks AniList to rank by text-match relevance instead
# of its default popularity/score ordering, so an exact title/name match
# surfaces first even if it's an obscure entry.
_SEARCH_MEDIA_QUERY = """
query ($search: String, $type: MediaType, $page: Int = 1, $perPage: Int = 20) {
  Page(page: $page, perPage: $perPage) {
    pageInfo {
      hasNextPage
    }
    media(search: $search, type: $type, sort: SEARCH_MATCH) {
      id
      title {
        userPreferred
        english
        romaji
      }
      format
      startDate {
        year
      }
      coverImage {
        large
      }
      averageScore
      favourites
      # Resolves against the currently authenticated viewer only (not
      # parameterized by user id) — null when this media isn't on the
      # viewer's list at all, which is exactly the "" sentinel
      # AnimeSearchCard's userStatus expects.
      mediaListEntry {
        status
      }
    }
  }
}
"""

_SEARCH_CHARACTERS_QUERY = """
query ($search: String, $page: Int = 1, $perPage: Int = 20) {
  Page(page: $page, perPage: $perPage) {
    pageInfo {
      hasNextPage
    }
    characters(search: $search, sort: SEARCH_MATCH) {
      id
      name {
        full
        native
        userPreferred
      }
      image {
        large
      }
    }
  }
}
"""

_SEARCH_STAFF_QUERY = """
query ($search: String, $page: Int = 1, $perPage: Int = 20) {
  Page(page: $page, perPage: $perPage) {
    pageInfo {
      hasNextPage
    }
    staff(search: $search, sort: SEARCH_MATCH) {
      id
      name {
        full
        native
        userPreferred
      }
      image {
        large
      }
    }
  }
}
"""

_SEARCH_STUDIOS_QUERY = """
query ($search: String, $page: Int = 1, $perPage: Int = 20) {
  Page(page: $page, perPage: $perPage) {
    pageInfo {
      hasNextPage
    }
    studios(search: $search, sort: SEARCH_MATCH) {
      id
      name
    }
  }
}
"""

_SEARCH_USERS_QUERY = """
query ($search: String, $page: Int = 1, $perPage: Int = 20) {
  Page(page: $page, perPage: $perPage) {
    pageInfo {
      hasNextPage
    }
    users(search: $search, sort: SEARCH_MATCH) {
      id
      name
      avatar {
        large
      }
    }
  }
}
"""

# NOTE: This is not a query for Anilist API. Its for animethemes.moe.
# animethemes GQL endopint: https://graphql.animethemes.moe
# This query gets the direct links for opening and endings for a given anime in video and audio formats
_OPENING_AND_ENDING_SONGS_QUERY = """
query ($id: [Int!]) {
    findAnimeByExternalSite(site: ANILIST, id: $id) {
        animethemes {
          id
          type
          song {
            title {
              romaji
            }
            performances {
              artist {
                images {
                  nodes {
                    link
                    facet
                  }
                }
                name {
                  main
                }
              }
            }
          }
          animethemeentries {
            episodes
            videos {
              nodes {
                basename  # File name with extension
                filename  # File name without extension
                source
                mimetype
                resolution
                size  # in bytes
                subbed
                link
                audio {
                  basename  # File name with extension
                  filename  # File name without extension
                  mimetype
                  size  # in bytes
                  link
                }
              }
            }
          }
        }
    }
}
"""